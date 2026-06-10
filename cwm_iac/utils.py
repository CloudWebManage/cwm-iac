import os
import time
import sys
import traceback
import json
import subprocess


def wait_for(func, wait_for=None, progress=None):
    if not wait_for:
        return func()
    else:
        while True:
            try:
                res = func()
            except Exception:
                traceback.print_exc(file=sys.stderr)
            else:
                if eval(wait_for) if isinstance(wait_for, str) else wait_for(res):
                    return res
                if progress:
                    print(json.dumps(
                        eval(progress) if isinstance(progress, str) else progress(res)
                    ), file=sys.stderr)
            time.sleep(1)


def envsubst(text, merge_env=None):
    return subprocess.check_output(
        ["envsubst"],
        text=True,
        input=text,
        env={
            **os.environ,
            **(merge_env or {})
        }
    )
