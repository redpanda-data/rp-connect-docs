# MCP Documentation Architecture: What Changed and Why

## The Old Structure (main branch)

```
Remote MCP/
├── Overview
├── Quickstart
├── Developer Guide     ← 1 monolithic page (~400 lines)
├── Admin Guide
│   ├── Manage Servers
│   ├── Scale Resources
│   └── Monitor Activity
└── MCP Server Patterns ← Called "pipeline-patterns"
```

**developer-guide.adoc was doing too much:**
- Concepts and architecture (what MCP tools are)
- Development workflow (how to build)
- Tool contract design (metadata, properties)
- Tags and organization
- Secrets management
- Testing and debugging
- Best practices (all inline)

**Problems:**
1. **No clear entry point by task** - Reader looking for "how do I debug?" has to scroll through concepts, workflow, contracts first
2. **Mixed audiences** - Concepts (for understanding) mixed with procedures (for doing)
3. **Can't link to specific topics** - "See the developer guide" doesn't tell you where
4. **Duplicate content** - rp-connect-docs had separate pages; cloud-docs had monolith
5. **pipeline-patterns name** - Confusing since MCP tools aren't pipelines

---

## The New Structure (current branch)

```
Remote MCP/
├── Overview            ← Evaluate: Should I use this?
├── Quickstart          ← Tutorial: First hands-on experience
├── Concepts            ← Understand: How does it work?
├── Create a Tool       ← How-to: Step-by-step task
├── Best Practices      ← Design guidance
├── Tool Patterns       ← Cookbook: Find reusable examples
├── Troubleshooting     ← Fix problems
└── Admin Guide
    ├── Manage Servers
    ├── Scale Resources
    └── Monitor Activity
```

**Each page has one clear purpose with measurable learning objectives.**

---

## Side-by-Side Comparison

| User Question | Old Structure | New Structure |
|---------------|---------------|---------------|
| "What is an MCP tool?" | Developer Guide (scroll to "Concepts and architecture") | **Concepts** page |
| "How do I create a tool?" | Developer Guide (scroll to "Development workflow") | **Create a Tool** page |
| "What should I name my tool?" | Developer Guide (scroll to "Design the tool contract") | **Best Practices** page |
| "Show me a database query example" | MCP Server Patterns | **Tool Patterns** (renamed) |
| "My tool isn't appearing" | Developer Guide (scroll to "Observe and debug") | **Troubleshooting** page |
| "How do tags work?" | Developer Guide (scroll to "Organize servers with tags") | **Best Practices** page |

---

## What We Split Out

### From developer-guide.adoc:

| Content | Now Lives In | Why |
|---------|--------------|-----|
| "Concepts and architecture" glossary | concepts.adoc | Conceptual content belongs in concepts |
| "Development workflow" numbered steps | create-tool.adoc | Task-based, belongs in how-to |
| "Design the tool contract" | create-tool.adoc + best-practices.adoc | Mechanics → how-to; naming → best practices |
| "Organize servers with tags" | best-practices.adoc | Design guidance |
| "Provision secrets" | create-tool.adoc | Part of the creation workflow |
| "Observe and debug" | troubleshooting.adoc | Problem-solving content |

### Renamed:

| Old Name | New Name | Why |
|----------|----------|-----|
| pipeline-patterns.adoc | tool-patterns.adoc | MCP tools aren't pipelines; avoids confusion |

---

## Benefits

### For Developers

| Benefit | How |
|---------|-----|
| **Find answers faster** | Each page has one topic; TOC shows exactly where to go |
| **Learn progressively** | Overview → Quickstart → Concepts → Create Tool (logical flow) |
| **Bookmark specific topics** | Link directly to troubleshooting or best practices |
| **Know what to expect** | Page type tells you: concepts = understanding, how-to = doing |

### For Documentation Team

| Benefit | How |
|---------|-----|
| **Single source of truth** | rp-connect-docs and cloud-docs share partials |
| **Easier maintenance** | Update one partial, both products get the fix |
| **Consistent structure** | Topic types guide what belongs where |
| **Measurable quality** | Each page has 4-6 learning objectives to verify |

### For Discoverability

| Benefit | How |
|---------|-----|
| **Better SEO** | Specific page titles rank for specific searches |
| **AI-friendly** | LLMs can retrieve focused pages instead of parsing monoliths |
| **Clear cross-references** | "See Troubleshooting" vs "See Developer Guide, debugging section" |

---

## Topic Type Taxonomy

| Type | Purpose | User Question | Example Page |
|------|---------|---------------|--------------|
| Overview | Evaluate/decide | "Should I use this?" | overview.adoc |
| Tutorial | First hands-on | "Show me how to start" | quickstart.adoc |
| Concepts | Mental model | "How does this work?" | concepts.adoc |
| How-to | Complete tasks | "How do I do X?" | create-tool.adoc |
| Best Practices | Design guidance | "What's the right way?" | best-practices.adoc |
| Cookbook | Reusable patterns | "Show me an example" | tool-patterns.adoc |
| Troubleshooting | Fix problems | "Something went wrong" | troubleshooting.adoc |

---

## Learning Objectives Example

### Old: developer-guide.adoc (implicit, unmeasurable)
*"This guide teaches you how to build MCP servers"* - No clear scope

### New: concepts.adoc (explicit, measurable)
```
After reading this page, you will be able to:
1. Explain what an MCP tool is and how it differs from a pipeline
2. Describe the request/response execution model
3. Map component types to their MCP tool purposes
4. Identify when each component type is appropriate
```

Each objective is testable: can the reader do this after reading?

---

## Single-Sourcing Architecture

```
rp-connect-docs (source of truth)
└── modules/ai-agents/partials/mcp/
    ├── key-terms.adoc
    ├── mcp-metadata-design.adoc
    ├── yaml-config-rules.adoc        ← Consolidated (was 2 files)
    ├── production-workflows.adoc     ← Consolidated (was 2 files)
    ├── secrets-connect.adoc
    └── secrets-cloud.adoc

cloud-docs (consumer)
└── modules/ai-agents/pages/mcp/remote/
    └── *.adoc files include partials via:
        include::redpanda-connect:ai-agents:partial$mcp/key-terms.adoc[]
```

Platform differences handled with conditionals:
```asciidoc
ifdef::env-cloud[]
Use ${secrets.NAME} syntax in Redpanda Cloud.
endif::[]
ifndef::env-cloud[]
Use environment variables or file-based secrets.
endif::[]
```

---

## Migration Summary

| Metric | Before | After |
|--------|--------|-------|
| Developer-facing pages | 3 (overview, quickstart, developer-guide) | 7 (overview, quickstart, concepts, create-tool, best-practices, tool-patterns, troubleshooting) |
| Average page length | ~400 lines (developer-guide) | ~100-150 lines each |
| Learning objectives | 0 explicit | 4-6 per page |
| Shared partials | Fragmented (6 files) | Consolidated (4 files) |
| Topic types used | 2 (overview, how-to) | 6 (overview, tutorial, concepts, how-to, best-practices, cookbook, troubleshooting) |

---

## Validation

- Both rp-connect-docs and cloud-docs build successfully
- All cross-references verified (no broken links)
- Test scripts aligned between products
- Partials render correctly with platform conditionals
