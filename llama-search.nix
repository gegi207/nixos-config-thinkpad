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
    openFirewall = true;
    model = "/srv/models/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf";
    host = "0.0.0.0";
    port = 8080;
    extraFlags = [ 
    "--jinja" "-t" "4" "-c" "8192" "--reasoning" "off" "--ui-mcp-proxy" 
    "--temp" "0.7" "--top-p" "0.8" "--top-k" "20" "--min-p" "0" "--presence-penalty" "1.5" ];
  };

  services.llama-cpp.package = pkgs.llama-cpp.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DGGML_NATIVE=OFF"
      "-DGGML_AVX=ON"
      "-DGGML_AVX2=ON"
      "-DGGML_FMA=ON"
      "-DGGML_F16C=ON"
     ];
  });

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
