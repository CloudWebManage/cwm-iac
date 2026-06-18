import json
import sys
import time

import click
import yaml
from click.shell_completion import CompletionItem

from . import api
from .. import utils


@click.group()
def cdn():
    pass


def _complete_tenant_name(ctx, param, incomplete):
    return [
        CompletionItem(name)
        for name in api.list_tenants()
        if name.startswith(incomplete)
    ]


@cdn.command()
@click.argument("name")
@click.argument("specfile", type=click.File("r"))
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
@click.option("--envsubst", is_flag=True)
def create_tenant(name, specfile, primary, secondary, envsubst):
    spec_str = specfile.read()
    if envsubst:
        spec_str = utils.envsubst(spec_str, {"TENANT_NAME": name})
    click.echo(json.dumps(api.create_tenant(name, yaml.safe_load(spec_str), primary, secondary), indent=2))


@cdn.command()
@click.argument("name", shell_complete=_complete_tenant_name)
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
@click.option("--wait-for")
@click.option("--progress")
def get_tenant(**kwargs):
    click.echo(json.dumps(api.get_tenant(**kwargs), indent=2))


@cdn.command()
@click.argument("name", shell_complete=_complete_tenant_name)
@click.option("--path", "paths", multiple=True, help="Exact path selector; may include a query string.")
@click.option("--url", "urls", multiple=True, help="Absolute tenant URL selector.")
@click.option("--prefix", "prefixes", multiple=True, help="Path prefix selector; query strings are ignored by the API.")
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
def purge_tenant(name, paths, urls, prefixes, primary, secondary):
    if not paths and not urls and not prefixes:
        raise click.UsageError("Provide at least one --path, --url, or --prefix selector")
    click.echo(json.dumps(api.purge_tenant(name, paths, urls, prefixes, primary, secondary), indent=2))


@cdn.command()
@click.argument("name", shell_complete=_complete_tenant_name)
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
def purge_tenant_everything(name, primary, secondary):
    click.echo(json.dumps(api.purge_tenant_everything(name, primary, secondary), indent=2))


@cdn.command()
@click.argument("specfile", type=click.File("r"))
@click.option("--envsubst", is_flag=True)
@click.option("--wait-for-failures", type=int, default=0)
def create_test_tenant(specfile, envsubst, wait_for_failures):
    name = f'test-{int(time.time())}'
    click.echo(f"Test tenant name: {name}", file=sys.stderr)
    spec_str = specfile.read()
    if envsubst:
        spec_str = utils.envsubst(spec_str, {"TENANT_NAME": name})
    click.echo(json.dumps(api.create_tenant(name, yaml.safe_load(spec_str)), indent=2), file=sys.stderr)
    if wait_for_failures:
        click.echo(json.dumps(api.get_tenant(
            name,
            wait_for=lambda res: res["ready"] == False,
            progress=lambda res: res['conditions'],
            wait_for_num=wait_for_failures,
        ), indent=2), file=sys.stderr)
    else:
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
@click.argument("name", shell_complete=_complete_tenant_name)
@click.option("--path", default="/anything/hello/world")
@click.option("--wait-for-success", is_flag=True)
@click.option("--wait-for-failures", type=int, default=0)
@click.option("--concurrency", type=int, default=0)
@click.option("--concurrent-requests", type=int, default=100)
def test_tenant(name, path, wait_for_success, wait_for_failures, concurrency, concurrent_requests):
    if concurrency:
        assert not wait_for_success and not wait_for_failures
        num_failures = 0
        for name, results in api.test_tenant_concurrent(name, concurrency, concurrent_requests, path=path).items():
            for result in results:
                if result[0] != 0:
                    print(f"--- {name} --- {result}")
                    num_failures += 1
        if num_failures > 0:
            click.echo(f"There were {num_failures} failures")
            sys.exit(1)
        else:
            click.echo("OK")
    elif wait_for_success:
        assert not wait_for_failures
        utils.wait_for(
            lambda: echo_test_tenant_results(api.test_tenant(name, path)),
            wait_for=lambda res: res == True,
        )
    elif wait_for_failures:
        utils.wait_for(
            lambda: echo_test_tenant_results(api.test_tenant(name, path)),
            wait_for=lambda res: res == False,
            wait_for_num=wait_for_failures,
        )
    else:
        echo_test_tenant_results(api.test_tenant(name, path))


@cdn.command()
@click.argument("name", shell_complete=_complete_tenant_name)
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
def delete_tenant(name, primary, secondary):
    click.echo(json.dumps(api.delete_tenant(name, primary, secondary), indent=2))


@cdn.command()
def delete_test_tenants():
    for name in api.list_tenants():
        if name.startswith("test-") and name.replace("test-", "").isdigit():
            click.echo(json.dumps(api.delete_tenant(name)))


@cdn.command()
def list_tenants():
    for name in api.list_tenants():
        click.echo(f'- "{name}"')


@cdn.command()
@click.argument("method")
@click.argument("path")
@click.option("--primary", is_flag=True)
@click.option("--secondary", is_flag=True)
@click.option("--kwargs-json")
def api_request(method, path, primary, secondary, kwargs_json):
    kwargs = json.loads(kwargs_json) if kwargs_json else {}
    click.echo(json.dumps(api.api_request(method, path, primary, secondary, **kwargs), indent=2))
