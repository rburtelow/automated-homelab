#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys

from rich.console import Console
from rich.panel import Panel
from rich.rule import Rule
from rich.table import Table
from rich.text import Text
from rich import box

INSTALLER = "factory.talos.dev/nocloud-installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b"
VERSION = "v1.13.4"
IMAGE = f"{INSTALLER}:{VERSION}"
TALOSCONFIG = "~/.talos/config"

console = Console()

# Result sentinel values
UPGRADED = "upgraded"
SKIPPED  = "skipped"
FAILED   = "failed"


def get_node_ips():
    result = subprocess.run(
        ["kubectl", "get", "nodes", "-o", "wide"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        console.print(f"[bold red]kubectl error:[/bold red] {result.stderr.strip()}")
        sys.exit(1)

    ips = []
    for line in result.stdout.splitlines()[1:]:  # skip header row
        parts = line.split()
        if len(parts) >= 6 and parts[5].startswith("192."):
            ips.append(parts[5])
    return ips


def get_node_version(ip):
    """Return the Talos version string running on the node, or None on failure."""
    result = subprocess.run(
        [
            "talosctl", "version",
            "--talosconfig", os.path.expanduser(TALOSCONFIG),
            "--nodes", ip,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None
    # Output contains Client and Server sections; grab the first Tag: after "Server:"
    in_server = False
    for line in result.stdout.splitlines():
        if line.strip().startswith("Server:"):
            in_server = True
        if in_server:
            m = re.search(r"Tag:\s+(v[\d.]+\S*)", line)
            if m:
                return m.group(1)
    return None


def upgrade_node(ip):
    cmd = [
        "talosctl", "upgrade",
        "--talosconfig", os.path.expanduser(TALOSCONFIG),
        "-n", ip,
        "--force",
        "--image", IMAGE,
    ]
    with console.status("  [dim]talosctl upgrade running...[/dim]", spinner="dots"):
        result = subprocess.run(cmd, capture_output=True, text=True)
    return result


def main():
    parser = argparse.ArgumentParser(description="Upgrade Talos nodes sequentially.")
    parser.add_argument(
        "--node", "-n",
        metavar="IP",
        help="Target a single node by IP instead of all discovered nodes.",
    )
    args = parser.parse_args()

    console.print()
    console.print(Panel(
        Text("Talos Cluster Upgrade", justify="center", style="bold cyan"),
        border_style="cyan",
        padding=(0, 4),
    ))
    console.print()

    # Config info
    cfg = Table(show_header=False, box=box.SIMPLE, padding=(0, 1))
    cfg.add_column(style="bold dim", no_wrap=True)
    cfg.add_column(style="cyan", overflow="fold")
    cfg.add_row("Target version", VERSION)
    cfg.add_row("Image", IMAGE)
    cfg.add_row("Config", TALOSCONFIG)
    if args.node:
        cfg.add_row("Node filter", args.node)
    console.print(cfg)
    console.print()

    # Discover nodes
    console.print(Rule("[dim]Discovering Nodes[/dim]", style="dim"))
    console.print()

    with console.status("[yellow]Querying kubectl...[/yellow]"):
        all_nodes = get_node_ips()

    if not all_nodes:
        console.print("[red]No nodes found with 192.x.x.x internal IPs.[/red]")
        sys.exit(1)

    if args.node:
        if args.node not in all_nodes:
            console.print(f"[red]Node {args.node} not found in cluster. Known IPs:[/red]")
            for ip in all_nodes:
                console.print(f"  [dim]{ip}[/dim]")
            sys.exit(1)
        nodes = [args.node]
    else:
        nodes = all_nodes

    # Check current versions
    with console.status("[yellow]Checking node versions...[/yellow]"):
        versions = {ip: get_node_version(ip) for ip in nodes}

    node_table = Table(box=box.ROUNDED, border_style="cyan")
    node_table.add_column("#", style="dim", width=4, justify="right")
    node_table.add_column("IP Address", style="bold")
    node_table.add_column("Current Version", justify="center")
    node_table.add_column("Action", justify="center")
    for i, ip in enumerate(nodes, 1):
        ver = versions[ip] or "[dim]unknown[/dim]"
        if versions[ip] == VERSION:
            ver_display = f"[green]{ver}[/green]"
            action = "[dim]skip[/dim]"
        else:
            ver_display = f"[yellow]{ver}[/yellow]"
            action = "[cyan]upgrade[/cyan]"
        node_table.add_row(str(i), ip, ver_display, action)
    console.print(node_table)
    console.print()

    # Upgrade each node sequentially
    console.print(Rule("[dim]Upgrading Nodes[/dim]", style="dim"))
    console.print()

    results = {}

    for i, ip in enumerate(nodes, 1):
        console.print(f"  [bold white]Node {i} of {len(nodes)}[/bold white]  [cyan]{ip}[/cyan]")

        if versions[ip] == VERSION:
            console.print(f"  [dim]Already on {VERSION} — skipping.[/dim]")
            console.print()
            results[ip] = SKIPPED
            continue

        result = upgrade_node(ip)
        success = result.returncode == 0
        results[ip] = UPGRADED if success else FAILED

        if result.stdout.strip():
            for line in result.stdout.strip().splitlines():
                console.print(f"    [dim]{line}[/dim]")

        if result.stderr.strip():
            color = "dim" if success else "red"
            for line in result.stderr.strip().splitlines():
                console.print(f"    [{color}]{line}[/{color}]")

        if success:
            console.print(f"  [green]✓[/green] [bold green]Upgrade complete[/bold green]")
        else:
            console.print(
                f"  [red]✗[/red] [bold red]Upgrade failed[/bold red]"
                f"  [dim](exit {result.returncode})[/dim]"
            )
        console.print()

    # Summary
    console.print(Rule("[dim]Summary[/dim]", style="dim"))
    console.print()

    summary = Table(box=box.ROUNDED, border_style="dim")
    summary.add_column("IP Address", style="cyan")
    summary.add_column("Result", justify="center")
    labels = {
        UPGRADED: "[green]✓  Upgraded[/green]",
        SKIPPED:  "[dim]–  Skipped[/dim]",
        FAILED:   "[red]✗  Failed[/red]",
    }
    for ip, status in results.items():
        summary.add_row(ip, labels[status])
    console.print(summary)
    console.print()

    failed  = [ip for ip, s in results.items() if s == FAILED]
    skipped = [ip for ip, s in results.items() if s == SKIPPED]
    upgraded = [ip for ip, s in results.items() if s == UPGRADED]

    if failed:
        console.print(f"  [bold red]{len(failed)} node(s) failed.[/bold red]\n")
        sys.exit(1)
    else:
        parts = []
        if upgraded:
            parts.append(f"[green]{len(upgraded)} upgraded[/green]")
        if skipped:
            parts.append(f"[dim]{len(skipped)} skipped[/dim]")
        console.print(f"  [bold]Done:[/bold] {', '.join(parts)}.\n")


if __name__ == "__main__":
    main()
