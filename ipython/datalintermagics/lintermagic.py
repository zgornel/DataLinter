import argparse
import shlex
from IPython.core.magic import (Magics, magics_class, line_magic, cell_magic)
import pandas as pd
import json
import http.client

TRACKED_VARIABLES = {}


@magics_class
class DataLinterMagic(Magics):
    tracked_variable = None
    data_header = None
    data_delim = None
    ip = None
    port = None
    show_stats = None
    show_na = None
    show_passing = None

    def __parse_add_linter_data_magic(self, line):
        try:
            parser = argparse.ArgumentParser()
            parser.add_argument("--tracked-variable")
            parser.add_argument("--data-header")
            parser.add_argument("--data-delim")
            args = parser.parse_args(shlex.split(line))
            #print(f">>DEBUG: Parsed %%add_linter_data line OK. args={args}")
            # tracked variable checks
            if args.tracked_variable is None:
                print("Warning (Linter): Please use '--tracked-variable' to specify a data variable!")
                return None
            tracked_variable = args.tracked_variable
            # data header checks
            data_header = True if args.data_header == 'True' else False
            if data_header is False and args.data_header != 'False' and args.data_header is not None:
                print("Warning (Linter): Wrong value for '--data-header', specify True / False. Assuming False...")
                return None
            # data delimiter checks
            data_delim = args.data_delim
            if data_delim is None:
                print("Warning (Linter): Please provide a data delimiter for '--data-delim'")
                return None
            return tracked_variable, data_header, data_delim
        except Exception as ex:
            print(f"Warning (Linter): Could not parse line for %%add_linter_data line magic:\n\t{ex}")
            return None

    def __parse_lint_magic(self, line):
        try:
            parser = argparse.ArgumentParser()
            parser.add_argument("--ip")
            parser.add_argument("--port")
            parser.add_argument("--show-stats")
            parser.add_argument("--show-na")
            parser.add_argument("--show-passing")
            args = parser.parse_args(shlex.split(line))
            #print(f">>DEBUG: Parsed %%lint line OK. args={args}")
            # ip
            if args.ip is None:
                print("Warning (Linter): Please use '--ip' to specify an ip")
                return None
            ip = args.ip
            #TODO: Implement IP correctness checks
            # port
            if args.port is None:
                print("Warning (Linter): Please use '--port' to specify a port")
                return None
            port = int(args.port)
            #TODO: Implement port conversion checks, perhaps default port
            # show_stats
            show_stats = True if args.show_stats == 'True' else False
            if show_stats is False and args.show_stats != 'False' and args.show_stats is not None:
                print("Warning (Linter): Wrong value for '--show-stats', specify True / False. Assuming False...")
                return None
            # show_na
            show_na = True if args.show_na == 'True' else False
            if show_na is False and args.show_na != 'False' and args.show_na is not None:
                print("Warning (Linter): Wrong value for '--show-na', specify True / False. Assuming False...")
                return None
            # show_passing
            show_passing = True if args.show_passing == 'True' else False
            if show_passing is False and args.show_passing != 'False' and args.show_passing is not None:
                print("Warning (Linter): Wrong value for '--show-passing', specify True / False. Assuming False...")
                return None
            return ip, port, show_stats, show_na, show_passing
        except Exception as ex:
            print(f"Warning (Linter): Could not parse line for %%lint cell magic:\n\t{ex}")
            return None

    @line_magic
    def add_linter_data(self, line):
        parsed_args = self.__parse_add_linter_data_magic(line)
        ipy = get_ipython()
        if parsed_args is not None:
            self.tracked_variable, self.data_header, self.data_delim = parsed_args
            try:
                TRACKED_VARIABLES[self.tracked_variable] = ipy.ev(self.tracked_variable)
            except Exception as ex:
                print(f"Warning (Linter): Variable '{tracked_variable}' not found in the current cell:\n\t{ex}")
        else:
            print(f">>DEBUG: '%add_linter_data' line magic FAILED (parsed_args={parsed_args})")

    #TODO: Support other variable types i.e. numpy arrays
    @cell_magic
    def lint(self, line, cell):
        parsed_args = self.__parse_lint_magic(line)
        if parsed_args is not None:
            self.ip, self.port, self.show_stats, self.show_na, self.show_passing = self.__parse_lint_magic(line)
            _df = TRACKED_VARIABLES[self.tracked_variable]
            _csv_df = self.dataframe_to_csv_string(_df)
            varbody = {
                        'linter_input': {
                            'context': {
                                'data': _csv_df,
                                'data_delim': self.data_delim,
                                'data_header': self.data_header,
                                'code': cell},
                            'options': {
                                'show_stats': self.show_stats,
                                'show_passing': self.show_passing,
                                'show_na': self.show_na}
                        }
                    }
            jsonbody = json.dumps(varbody)
            try:
                linter_response_json = self.http_lint_request(jsonbody)
                linter_response = json.loads(linter_response_json)
                print(f"Linter output\n-------------\n{linter_response['linting_output']}")
            except Exception as ex:
                print(f"Warning (Linter): Failed to read linter output (perhaps linting failed):\n\t{ex}")
        else:
            print(f">>DEBUG: '%%lint' cell magic FAILED (parsed_args={parsed_args})")
        return None

    def numpy_array_to_csv_string(self, arr):
        df = pd.DataFrame(arr)
        self.dataframe_to_csv_string(df)

    def dataframe_to_csv_string(self, df):
        _header = False
        _colnames = list(df.columns)
        if self.data_header is True and _colnames:
            _header = _colnames
        elif self.data_header is True and not _colnames:
            _header = ['x'+str(i) for i in range(len(df.columns))]
        else:
            pass
        return df.to_csv(None, sep=self.data_delim, header=_header, index=False)


    def http_lint_request(self, body):
        host = self.ip
        conn = http.client.HTTPConnection(host, self.port)
        conn.request("POST", "/api/lint", body=body, )
        response = conn.getresponse()
        print(f"Response: {response.status}, {response.reason}")
        return response.read().decode()
