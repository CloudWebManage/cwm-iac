"""Disposable Docker checks; work even when the Docker host has a different /tmp."""
from contextlib import contextmanager
import io
import subprocess
import tarfile


def docker(*args, **kwargs):
    return subprocess.run(["docker", *args], capture_output=True, check=True, **kwargs)


def copy_files(container, files):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w") as archive:
        for name, content in files.items():
            data = content.encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            archive.addfile(info, io.BytesIO(data))
    docker("cp", "-", f"{container}:/", input=stream.getvalue())


@contextmanager
def container(image, args=(), files=None, options=()):
    identifier = docker("create", *options, image, *args, text=True).stdout.strip()
    try:
        if files:
            copy_files(identifier, files)
        yield identifier
    finally:
        docker("rm", "-f", "-v", identifier, text=True)
