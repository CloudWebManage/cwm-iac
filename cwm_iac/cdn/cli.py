import json
import sys
import time

import click
import yaml

from . import api
from .. import utils


@click.group()
def cdn():
    pass


@cdn.command()
@click.argument("name")
@click.argument("specfile", type=click.File("r"))
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
@click.option("--envsubst", is_flag=True)
def create_tenant(name, specfile, primary, secondary, envsubst):
    spec_str = specfile.read()
    if envsubst:
        spec_str = utils.envsubst(spec_str)
    click.echo(json.dumps(api.create_tenant(name, yaml.safe_load(spec_str), primary, secondary), indent=2))


@cdn.command()
@click.argument("name")
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
@click.option("--wait-for")
@click.option("--progress")
def get_tenant(**kwargs):
    click.echo(json.dumps(api.get_tenant(**kwargs), indent=2))


@cdn.command()
@click.argument("specfile", type=click.File("r"))
@click.option("--envsubst", is_flag=True)
def create_test_tenant(specfile, envsubst):
    name = f'test-{int(time.time())}'
    click.echo(f"Test tenant name: {name}", file=sys.stderr)
    spec_str = specfile.read()
    if envsubst:
        spec_str = utils.envsubst(spec_str, {"TENANT_NAME": name})
    click.echo(json.dumps(api.create_tenant(name, yaml.safe_load(spec_str)), indent=2), file=sys.stderr)
    click.echo(json.dumps(api.get_tenant(
        name,
        wait_for=lambda res: res["ready"] == True,
        progress=lambda res: res['conditions'],
    ), indent=2), file=sys.stderr)
    utils.wait_for(
        lambda: echo_test_tenant_results(api.test_tenant(name)),
        wait_for=lambda res: res == True,
    )
    click.echo(json.dumps(api.delete_tenant(name), indent=2), file=sys.stderr)


def echo_test_tenant_results(results):
    result_returncoe = {}
    for result_name, result in results.items():
        returncode, stdout, stderr = result
        click.echo(f"--- {result_name} ---")
        click.echo(stdout)
        if returncode != 0:
            click.echo(f"stderr: {stderr}")
            click.echo(f"returncode: {returncode}")
        click.echo("")
        result_returncoe[result_name] = returncode
    click.echo("Returncodes")
    all_good = True
    for result_name, returncode in result_returncoe.items():
        click.echo(f"{result_name}: {returncode}")
        if returncode != 0:
            all_good = False
    return all_good


@cdn.command()
@click.argument("name")
@click.option("--path", default="/anything/hello/world")
@click.option("--wait-for-success", is_flag=True)
def test_tenant(name, path, wait_for_success):
    if wait_for_success:
        utils.wait_for(
            lambda: echo_test_tenant_results(api.test_tenant(name, path)),
            wait_for=lambda res: res == True,
        )
    else:
        echo_test_tenant_results(api.test_tenant(name, path))


@cdn.command()
@click.argument("name")
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
def delete_tenant(name, primary, secondary):
    click.echo(json.dumps(api.delete_tenant(name, primary, secondary), indent=2))


@cdn.command()
def delete_test_tenants():
    for name in api.list_tenants():
        if name.startswith("test-") and name.replace("test-", "").isdigit():
            click.echo(json.dumps(api.delete_tenant(name)))
