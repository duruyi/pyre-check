#!/usr/bin/env python3

import os
from typing import Optional

import click
import IPython
from click import Choice, Parameter, Path, argument, group, option
from sapp.analysis_output import AnalysisOutput
from sapp.database_saver import DatabaseSaver
from sapp.db import DB, DBType
from sapp.interactive import Interactive
from sapp.model_generator import ModelGenerator
from sapp.models import PrimaryKeyGenerator
from sapp.pipeline import Pipeline
from sapp.pysa_taint_parser import Parser
from sapp.trim_trace_graph import TrimTraceGraph

from .context import Context, pass_context
from .filesystem import find_root


MARKER_DIRECTORIES = [".pyre", ".hg", ".git", ".svn"]


def default_database(ctx: click.Context, _param: Parameter, value: Optional[str]):
    """Try to guess a reasonable database name by looking at the repository
    path and database engine"""
    if value:
        return value

    if ctx.params["database_engine"] == DBType.MEMORY:
        return ":memory:"

    if ctx.params["repository"]:
        return os.path.join(ctx.params["repository"], DB.DEFAULT_DB_FILE)

    raise click.BadParameter("Could not guess a database location")


@group()
@option(
    "--repository",
    "-r",
    default=lambda: find_root(MARKER_DIRECTORIES),
    type=Path(exists=True, file_okay=False),
    help="Root of the repository (regardless of the directory analyzed)",
)
@option(
    "--database-engine",
    "--database",
    type=Choice([DBType.SQLITE, DBType.MEMORY]),
    default=DBType.SQLITE,
    help="database engine to use",
)
@option(
    "--database-name", "--dbname", callback=default_database, type=Path(dir_okay=False)
)
@click.pass_context
def cli(
    ctx: click.Context,
    repository: Optional[str],
    database_engine: DBType,
    database_name: Optional[str],
):
    ctx.obj = Context(
        repository=repository,
        database_engine=database_engine,
        database_name=database_name,
    )


@cli.command(help="interactive exploration of issues")
@pass_context
def explore(ctx: Context):
    scope_vars = Interactive(
        ctx.database_engine, ctx.database_name, ctx.repository
    ).setup()
    IPython.start_ipython(argv=[], user_ns=scope_vars)


@cli.command(help="parse static analysis output and save to disk")
@pass_context
@option("--run-kind", type=str)
@option("--branch", type=str)
@option("--commit-hash", type=str)
@option("--job-id", type=str)
@option("--differential-id", type=int)
@option(
    "--previous-issue-handles",
    type=Path(exists=True),
    help=(
        "file containing list of issue handles to compare INPUT_FILE to "
        "(preferred over --previous-input)"
    ),
)
@option(
    "--previous-input",
    type=Path(exists=True),
    help="static analysis output to compare INPUT_FILE to",
)
@option(
    "--linemap",
    type=Path(exists=True),
    help="json file mapping new locations to old locations",
)
@option(
    "--store-unused-models",
    is_flag=True,
    help="store pre/post conditions unrelated to an issue",
)
@argument("input_file", type=Path(exists=True))
def analyze(
    ctx: Context,
    run_kind,
    branch,
    commit_hash,
    job_id,
    differential_id,
    previous_issue_handles,
    previous_input,
    linemap,
    store_unused_models,
    input_file,
):
    # Store all options in the right places
    summary_blob = {
        "run_kind": run_kind,
        "compress": lambda x: x,
        "repository": ctx.repository,
        "branch": branch,
        "commit_hash": commit_hash,
        "old_linemap_file": linemap,
        "store_unused_models": store_unused_models,
    }

    if job_id is None and differential_id is not None:
        job_id = "user_input_" + str(differential_id)
    summary_blob["job_id"] = job_id

    if previous_issue_handles:
        summary_blob["previous_issue_handles"] = AnalysisOutput.from_file(
            previous_issue_handles
        )
    elif previous_input:
        previous_input = AnalysisOutput.from_file(previous_input)

    # Construct pipeline
    input_files = (AnalysisOutput.from_file(input_file), previous_input)
    pipeline_steps = [
        Parser(),
        ModelGenerator(),
        TrimTraceGraph(),
        DatabaseSaver(
            DB(ctx.database_engine, ctx.database_name, assertions=True),
            PrimaryKeyGenerator(),
        ),
    ]
    pipeline = Pipeline(pipeline_steps)
    pipeline.run(input_files, summary_blob)


if __name__ == "__main__":
    cli()
