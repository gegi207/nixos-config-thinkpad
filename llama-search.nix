{ config, pkgs, lib, ... }:

let
  # Tiny MCP server that exposes SearXNG as a "search" tool (Streamable HTTP)
  pyEnv = pkgs.python3.withPackages (ps: [ ps.fastmcp ps.httpx ]);

  bridge = pkgs.writeText "searx_mcp.py" ''
    import httpx
    from fastmcp import FastMCP

    mcp = FastMCP("searxng")

    @mcp.tool()
    def search(query: str, max_results: int = 5) -> list[dict]:
        """Search the web. Returns title, url and snippet for each result."""
        r = httpx.get(
            "http://127.0.0.1:8888/search",
            params={"q": query, "format": "json"},
            timeout=20,
        )
        r.raise_for_status()
        return [
            {"title": x["title"], "url": x["url"], "content": x.get("content", "")}
            for x in r.json()["results"][:max_results]
        ]

    if __name__ == "__main__":
        mcp.run(transport="http", host="127.0.0.1", port=8000)
  '';
in
{
  # 1. The model server (web UI at http://localhost:8080)
  services.llama-cpp = {
    enable = true;
    # Download a GGUF yourself and put it somewhere world-readable
    model = "/srv/models/LFM2.5-24B-A2B-Q4_K_m.gguf";
    host = "127.0.0.1";
    port = 8080;
    extraFlags = [
      "--jinja"          # needed for tool calling
      "-t" "8"           # set to your physical core count
      "-c" "16384"       # context size; search results eat context
      "--ui-mcp-proxy"   # lets the web UI reach MCP servers (older name: --webui-mcp-proxy)
    ];
  };

  # 2. Private search engine
  services.searx = {
    enable = true;
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        secret_key = "12345678";
      };
      search.formats = [ "html" "json" ];  # json is required by the bridge
    };
  };

  # 3. MCP bridge (http://127.0.0.1:8000/mcp)
  systemd.services.searxng-mcp = {
    description = "SearXNG MCP bridge";
    after = [ "searx.service" ];
    # wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pyEnv}/bin/python ${bridge}";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };
  # 4. prevent autostart on boot
  systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];
  systemd.services.searx.wantedBy = lib.mkForce [ ];
  systemd.services.searxng-mcp.wantedBy = lib.mkForce [ "multi-user.target" ];  
}
