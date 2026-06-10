import importlib

import click


@click.group()
def main():
    pass


main.add_command(importlib.import_module(".cdn.cli", __package__).cdn)
