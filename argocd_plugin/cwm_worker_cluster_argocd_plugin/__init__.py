import sys


def init(chart_path):
    pass


def generate_template(cmd, cwd, data):
    print('generate_template', cmd, cwd, str(data), file=sys.stderr)
    return cmd, cwd
