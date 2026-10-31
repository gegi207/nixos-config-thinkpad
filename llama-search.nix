{ config, pkgs, lib, ... }:

let
  pyEnv = pkgs.python3.withPackages (ps: [ ps.fastmcp ps.httpx ]);

  # MCP bridge: exposes Tavily as a "search" tool (Streamable HTTP)
  bridge = pkgs.writeText "tavily_mcp.py" ''
    import os
    import httpx
    from fastmcp import FastMCP

    mcp = FastMCP("tavily")

    @mcp.tool()
    def search(query: str, max_results: int = 5) -> list[dict]:
        """Search the web. Returns title, url and snippet for each result."""
        r = httpx.post(
            "https://api.tavily.com/search",
            headers={"Authorization": "Bearer " + os.environ["TAVILY_API_KEY"]},
            json={"query": query, "max_results": max_results, "search_depth": "basic"},
            timeout=30,
        )
        r.raise_for_status()
        return [
            {"title": x["title"], "url": x["url"], "content": x.get("content", "")}
            for x in r.json()["results"]
        ]

    if __name__ == "__main__":
        mcp.run(transport="http", host="127.0.0.1", port=8000)
  '';
in
{
  services.llama-cpp = {
    enable = true;
    model = "/srv/models/LFM2.5-24B-A2B-Q4_K_m.gguf";
    host = "0.0.0.0";
    port = 8080;
    extraFlags = [ "--jinja" "-t" "4" "-c" "16384" "--ui-mcp-proxy" ];
  };

  systemd.services.search-mcp = {
      description = "Tavily MCP bridge";
      # wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pyEnv}/bin/python ${bridge}";
        # File containing one line:  TAVILY_API_KEY=tvly-xxxxxxxx
        # Kept outside the Nix store so the key isn't world-readable
        EnvironmentFile = "/etc/tavily.env";
        DynamicUser = true;
        Restart = "on-failure";
      };
    };

    # Optional: don't start at boot, start manually instead
    systemd.services.llama-cpp.wantedBy = lib.mkForce [ ];
    systemd.services.search-mcp.wantedBy = lib.mkForce [ "multi-user.target" ];
}
