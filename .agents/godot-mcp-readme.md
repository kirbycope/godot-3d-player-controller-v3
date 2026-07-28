# Local Godot Docs MCP Server Setup & Usage Guide

This guide documents the setup and usage of the local **Godot Engine Documentation MCP (Model Context Protocol) Server**. It enables AI coding assistants to search and read local Godot documentation directly from a cloned copy of the official `godot-docs` repository.

---

## 🛠️ Prerequisites

- **Node.js**: v18.x or later installed on your system.
- **Git**: Installed for cloning the documentation repository.

---

## 📁 Recommended Directory Structure

To ensure cross-platform compatibility across **macOS**, **Windows**, and **Linux**, place the `godot-docs` repository as a sibling folder to your project:

```text
GitHub/ (or your development folder)
├── godot-3d-player-controller-v3/    # Workspace Project
│   └── .agents/
│       ├── mcp_config.json           # MCP Configuration file
│       └── godot-mcp-readme.md       # This guide
└── godot-docs/                       # Cloned Godot Docs repository
    ├── index.mjs                     # MCP Server executable
    └── package.json                  # Node dependencies (@modelcontextprotocol/sdk, glob)
```

---

## 🚀 Setup Instructions

### 1. Clone the Godot Docs Repository

In your main development directory (e.g., `C:\GitHub` on Windows or `~/GitHub` on macOS/Linux), run:

```bash
git clone https://github.com/godotengine/godot-docs.git godot-docs
```

### 2. Create the MCP Server Script (`godot-docs/index.mjs`)

Inside the `godot-docs` folder, ensure `index.mjs` contains the following server logic:

```javascript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { glob } from "glob";

// Automatically detects the folder index.mjs lives in on any OS (macOS/Windows/Linux)
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOCS_DIR = process.env.GODOT_DOCS_PATH || __dirname;

const server = new Server(
    { name: "godot-docs-local", version: "1.0.0" },
    { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            {
                name: "search_godot_docs",
                description: "Search local Godot documentation (.rst files) for keyword or topic",
                inputSchema: {
                    type: "object",
                    properties: {
                        query: { type: "string", description: "Search keyword (e.g., CharacterBody3D, signals)" }
                    },
                    required: ["query"]
                }
            },
            {
                name: "read_godot_doc_file",
                description: "Read full content of a specific documentation file",
                inputSchema: {
                    type: "object",
                    properties: {
                        relativePath: { type: "string", description: "Relative file path from godot-docs root (e.g., classes/class_characterbody3d.rst)" }
                    },
                    required: ["relativePath"]
                }
            }
        ]
    };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    if (name === "search_godot_docs") {
        const query = args.query.toLowerCase();
        const files = await glob("**/*.rst", { cwd: DOCS_DIR });
        const matches = [];

        for (const file of files) {
            const fullPath = path.join(DOCS_DIR, file);
            const content = fs.readFileSync(fullPath, "utf8");
            if (content.toLowerCase().includes(query)) {
                matches.push(file);
                if (matches.length >= 10) break;
            }
        }

        return {
            content: [{ type: "text", text: JSON.stringify(matches, null, 2) }]
        };
    }

    if (name === "read_godot_doc_file") {
        const filePath = path.join(DOCS_DIR, args.relativePath);
        if (!fs.existsSync(filePath)) {
            return { isError: true, content: [{ type: "text", text: "File not found." }] };
        }
        const content = fs.readFileSync(filePath, "utf8");
        return {
            content: [{ type: "text", text: content }]
        };
    }

    throw new Error(`Tool not found: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 3. Install Dependencies in `godot-docs`

Run the following inside your `godot-docs` directory:

```bash
npm init -y
npm install @modelcontextprotocol/sdk glob
```

### 4. Configure `mcp_config.json` in Your Workspace

In your project repository, edit `.agents/mcp_config.json`:

```json
{
	"mcpServers": {
		"godot-docs": {
			"command": "node",
			"args": [
				"../godot-docs/index.mjs"
			]
		}
	}
}
```

---

## 💡 Usage Notes & Available Tools

Once configured, the AI assistant automatically discovers and uses the following tools over `stdio`:

1. **`search_godot_docs`**
   - **Input**: `{ "query": "CharacterBody3D" }`
   - **Behavior**: Scans `.rst` files in the local documentation repository for matching keywords and returns relative file paths.

2. **`read_godot_doc_file`**
   - **Input**: `{ "relativePath": "classes/class_characterbody3d.rst" }`
   - **Behavior**: Retrieves the full markdown/reStructuredText content of the specified documentation file.

---

## 🌍 Cross-Platform Compatibility

- **Dynamic Path Resolution**: `index.mjs` uses `import.meta.url` to dynamically resolve paths at runtime. It works seamlessly whether your environment is on macOS (`/Users/.../GitHub/godot-docs`), Windows (`C:\GitHub\godot-docs`), or Linux (`/home/.../GitHub/godot-docs`).
- **Relative Tool Arguments**: Using `"../godot-docs/index.mjs"` in `mcp_config.json` avoids hardcoding OS-specific drive letters or home directory structures.
