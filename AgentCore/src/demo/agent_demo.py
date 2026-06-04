#!/usr/bin/env python3
"""
AgentCore Memory — Demo Script
=================================
Demonstrates all 3 memory layers by invoking the Bedrock Agent.

Usage:
    python3 agent_demo.py --agent-id WCBKSI4LCW --alias-id 2FESL8UO5D --layer all
    python3 agent_demo.py --agent-id WCBKSI4LCW --alias-id 2FESL8UO5D --layer layer1
    python3 agent_demo.py --agent-id WCBKSI4LCW --alias-id 2FESL8UO5D --layer layer3

Prerequisites:
    - AWS credentials configured
    - Agent deployed via Terraform
    - pip install boto3
"""

import argparse
import json
import sys
import time
import uuid
from datetime import datetime

try:
    import boto3
except ImportError:
    print("ERROR: boto3 not installed. Run: pip install boto3")
    sys.exit(1)


# ── ANSI Colors ──────────────────────────────────────────────────────────────

class C:
    HEADER  = "\033[95m"
    BLUE    = "\033[94m"
    CYAN    = "\033[96m"
    GREEN   = "\033[92m"
    YELLOW  = "\033[93m"
    RED     = "\033[91m"
    BOLD    = "\033[1m"
    DIM     = "\033[2m"
    END     = "\033[0m"


def print_header(text):
    print(f"\n{C.BOLD}{C.HEADER}{'═' * 60}")
    print(f"  {text}")
    print(f"{'═' * 60}{C.END}\n")


def print_user(text):
    print(f"  {C.CYAN}{C.BOLD}👤 User:{C.END} {text}")


def print_agent(text):
    print(f"  {C.GREEN}{C.BOLD}🤖 Agent:{C.END} {text}")


def print_info(text):
    print(f"  {C.DIM}ℹ️  {text}{C.END}")


def print_step(num, text):
    print(f"\n  {C.YELLOW}{C.BOLD}Step {num}:{C.END} {text}")


# ── Agent Invocation ─────────────────────────────────────────────────────────

def invoke_agent(client, agent_id, alias_id, session_id, prompt):
    """Invoke the Bedrock Agent and return the response text."""
    response = client.invoke_agent(
        agentId=agent_id,
        agentAliasId=alias_id,
        sessionId=session_id,
        inputText=prompt,
    )

    # Stream the response
    result_text = ""
    for event in response.get("completion", []):
        if "chunk" in event:
            chunk_text = event["chunk"]["bytes"].decode("utf-8")
            result_text += chunk_text

    return result_text.strip()


# ── Layer 1 Demo: In-Context Memory ─────────────────────────────────────────

def demo_layer1(client, agent_id, alias_id):
    print_header("Layer 1 — In-Context Memory (Prompt Window)")
    print_info("The agent recalls from its current prompt context. Zero latency.")

    session_id = f"demo-layer1-{uuid.uuid4().hex[:8]}"
    print_info(f"Session ID: {session_id}")

    print_step(1, "Tell the agent your name")
    prompt1 = "My name is Pushparaj and I'm building AI agents on AWS."
    print_user(prompt1)
    resp1 = invoke_agent(client, agent_id, alias_id, session_id, prompt1)
    print_agent(resp1)

    print_step(2, "Ask the agent to recall your name (same session)")
    prompt2 = "I mentioned my name earlier — what is it?"
    print_user(prompt2)
    resp2 = invoke_agent(client, agent_id, alias_id, session_id, prompt2)
    print_agent(resp2)

    print(f"\n  {C.GREEN}✅ Layer 1 demo complete — agent recalled from prompt context{C.END}")


# ── Layer 2 Demo: Session Summary ───────────────────────────────────────────

def demo_layer2(client, agent_id, alias_id):
    print_header("Layer 2 — SESSION_SUMMARY (Bedrock Auto-Summary)")
    print_info("Bedrock generates a rolling summary injected into subsequent turns.")

    session_id = f"demo-layer2-{uuid.uuid4().hex[:8]}"
    print_info(f"Session ID: {session_id}")

    turns = [
        "I prefer Terraform over CDK for infrastructure management.",
        "My tech stack includes Python, AWS Lambda, and Bedrock.",
        "I'm working on an article about agent memory patterns.",
    ]

    for i, turn in enumerate(turns, 1):
        print_step(i, f"Establish preference (turn {i})")
        print_user(turn)
        resp = invoke_agent(client, agent_id, alias_id, session_id, turn)
        print_agent(resp)

    print_step(4, "Ask for a session summary")
    prompt_summary = "Summarise what you know about me from this session."
    print_user(prompt_summary)
    resp_summary = invoke_agent(client, agent_id, alias_id, session_id, prompt_summary)
    print_agent(resp_summary)

    print(f"\n  {C.GREEN}✅ Layer 2 demo complete — Bedrock auto-generated the summary{C.END}")


# ── Layer 3 Demo: Long-Term Cross-Session ────────────────────────────────────

def demo_layer3(client, agent_id, alias_id):
    print_header("Layer 3 — Long-Term Memory (Aurora pgvector)")
    print_info("Facts saved in Session A are retrieved in Session B via semantic search.")

    # Session A: Save a fact
    session_a = f"demo-layer3-a-{uuid.uuid4().hex[:8]}"
    print_info(f"Session A ID: {session_a}")

    print_step(1, "Save a fact to long-term memory (Session A)")
    save_prompt = (
        "Please save this to my long-term memory: "
        "I always prefer eu-west-1 as my primary AWS region because my users "
        "are in Europe. Confidence: high."
    )
    print_user(save_prompt)
    resp_save = invoke_agent(client, agent_id, alias_id, session_a, save_prompt)
    print_agent(resp_save)

    # Wait for KB ingestion
    print_info("Waiting 30s for KB ingestion pipeline to complete...")
    for i in range(30, 0, -1):
        print(f"\r  {C.DIM}  ⏳ {i}s remaining...{C.END}", end="", flush=True)
        time.sleep(1)
    print()

    # Session B: Retrieve the fact
    session_b = f"demo-layer3-b-{uuid.uuid4().hex[:8]}"
    print_info(f"Session B ID: {session_b}")

    print_step(2, "Retrieve the fact from a NEW session (Session B)")
    retrieve_prompt = "What do you know about my preferred AWS region from long-term memory?"
    print_user(retrieve_prompt)

    start = time.time()
    resp_retrieve = invoke_agent(client, agent_id, alias_id, session_b, retrieve_prompt)
    latency = (time.time() - start) * 1000

    print_agent(resp_retrieve)
    print_info(f"Retrieval latency: {latency:.0f}ms")

    print(f"\n  {C.GREEN}✅ Layer 3 demo complete — cross-session retrieval working{C.END}")


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="AgentCore Memory — Demo all 3 memory layers"
    )
    parser.add_argument("--agent-id", required=True, help="Bedrock Agent ID")
    parser.add_argument("--alias-id", required=True, help="Agent Alias ID")
    parser.add_argument(
        "--layer",
        choices=["layer1", "layer2", "layer3", "all"],
        default="all",
        help="Which layer(s) to demo",
    )
    parser.add_argument("--region", default="eu-west-1", help="AWS region")
    args = parser.parse_args()

    client = boto3.client("bedrock-agent-runtime", region_name=args.region)

    print(f"\n{C.BOLD}{C.BLUE}🧠 AgentCore Memory — Live Demo{C.END}")
    print(f"{C.DIM}  Agent: {args.agent_id}  |  Alias: {args.alias_id}  |  Region: {args.region}")
    print(f"  Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{C.END}")

    demos = {
        "layer1": demo_layer1,
        "layer2": demo_layer2,
        "layer3": demo_layer3,
    }

    if args.layer == "all":
        for name, func in demos.items():
            func(client, args.agent_id, args.alias_id)
    else:
        demos[args.layer](client, args.agent_id, args.alias_id)

    print(f"\n{C.BOLD}{C.GREEN}🎉 All demos complete!{C.END}\n")


if __name__ == "__main__":
    main()
