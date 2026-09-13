"""Check Mira's background callbacks against a supplied webhooks.py module."""

import argparse
import ast
import asyncio
from pathlib import Path


class RecordingLogger:
    def __init__(self):
        self.warnings = []

    def warning(self, message, error):
        self.warnings.append((message, error))


def load_callbacks(source, logger):
    tree = ast.parse(source)
    callbacks = [
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.Lambda)
        and any(label in ast.unparse(node) for label in ["Vuln poller crashed", "Backfill failed"])
    ]
    if len(callbacks) != 2:
        raise AssertionError("Expected backfill and vulnerability poller callbacks")
    loaded = []
    for node in callbacks:
        label = next(
            child.value
            for child in ast.walk(node)
            if isinstance(child, ast.Constant)
            and isinstance(child.value, str)
            and child.value.endswith(": %s")
        )
        expression = ast.Expression(body=node)
        callback = eval(compile(expression, "<Mira callback>", "eval"), {"logger": logger})
        loaded.append((label, callback))
    return loaded


async def check_callback(label, callback, logger):
    logger.warnings.clear()

    cancelled = asyncio.create_task(asyncio.sleep(60))
    cancelled.cancel()
    try:
        await cancelled
    except asyncio.CancelledError:
        pass
    callback(cancelled)
    assert not logger.warnings, "Cancellation must not log a task failure"

    completed = asyncio.create_task(asyncio.sleep(0))
    await completed
    callback(completed)
    assert not logger.warnings, "Successful completion must not log a task failure"

    failure = RuntimeError("verification failure")

    async def fail():
        raise failure

    failed = asyncio.create_task(fail())
    try:
        await failed
    except RuntimeError:
        pass
    callback(failed)
    assert logger.warnings == [(label, failure)], (
        "Real failures must still reach the logger"
    )


async def check(source):
    logger = RecordingLogger()
    for label, callback in load_callbacks(source, logger):
        await check_callback(label, callback, logger)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("module", type=Path)
    arguments = parser.parse_args()
    asyncio.run(check(arguments.module.read_text()))
    print("Cancellation, success, and real failure callbacks passed.")
