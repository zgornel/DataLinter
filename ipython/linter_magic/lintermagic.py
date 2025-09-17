import argparse
import shlex
from IPython.core.magic import (Magics, magics_class, line_magic, cell_magic)

DATA = {}

@magics_class
class LinterFoo(Magics):

    def __parse_line(self, line):
        parser = argparse.ArgumentParser()
        parser.add_argument("data")
        parser.add_argument("--data-header")
        parser.add_argument("--data-delim")
        parser.add_argument("--show-stats")
        parser.add_argument("--show-na")
        parser.add_argument("--show-passing")
        args = parser.parse_args(shlex.split(line))
        print(f"Parsed line: {args}")
        return args


    @line_magic
    def lint_line(self, line):
        print("Not implemented, should lint:\n$\'line\'")
        return None

    @line_magic
    def linter_data(self, line):
        linter_args = None
        try:
            print(f"LINE: {line}")
            linter_args = self.__parse_line(line)
        except:
            print(f"Warning (Linter): Could not parse %%linter_data magic")
            return None
        ipy = get_ipython()
        if linter_args is not None:
            data_var = linter_args.data
            try:
                DATA[data_var] = ipy.ev(data_var)
            except Exception as ex:
                print(f"Warning (Linter): Variable '{item}' not found in the current cell.\n{e}")
            print(DATA)
        else:
            print(f"Warning (Linter): Something did not work")

    @cell_magic
    def lint_cell(self, line, cell):
        # print(cell)
        # return line, cell
        return line, cell
