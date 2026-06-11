import os
import time
import sys
import traceback
import json
import subprocess


def wait_for(func, wait_for=None, progress=None, timeout_seconds=360, sleep_seconds=5, wait_for_num=0):
    if not wait_for:
        return func()
    else:
        start_time = time.time()
        num_completed = 0
        while True:
            try:
                res = func()
            except Exception:
                if time.time() - start_time > timeout_seconds:
                    raise
                else:
                    traceback.print_exc(file=sys.stderr)
            else:
                if eval(wait_for) if isinstance(wait_for, str) else wait_for(res):
                    if wait_for_num:
                        num_completed += 1
                        if num_completed >= wait_for_num:
                            return res
                    else:
                        return res
                if progress:
                    print(json.dumps(
                        eval(progress) if isinstance(progress, str) else progress(res)
                    ), file=sys.stderr)
            if time.time() - start_time > timeout_seconds:
                raise TimeoutError()
            time.sleep(sleep_seconds)


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
