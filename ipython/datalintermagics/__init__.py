"""IPython magic for DataLinter"""
__version__ = '0.0.1'


from .lintermagic import DataLinterMagic


def load_ipython_extension(ipython):
    ipython.register_magics(DataLinterMagic)
