-- web_render: render a JavaScript page with the pinned Lightpanda binary and
-- return its Markdown. The binary installs as bin/fiber-lightpanda (the last
-- segment of the manifest name). Lightpanda is AGPL-3.0 and is not in this repo.

local TERMINATE_MS = 60000 -- Lightpanda aborts the page after this
local DUMP_MAX_BYTES = 1048576 -- soft cap on what Lightpanda prints; Fiber's own result cap then applies

fiber.tool("web_render", {
  description = "Load a web page in a headless browser that runs its JavaScript, "
    .. "and return the rendered page as Markdown. Use it when web_fetch returns a "
    .. "page without its content, such as a client-side rendered app. Slower than "
    .. "web_fetch; do not use it for pages web_fetch already reads. Refuses private "
    .. "network addresses.",
  input_schema = {
    type = "object",
    required = { "url" },
    properties = {
      url = { type = "string", description = "The http or https URL of the page." },
    },
  },
  effects = { effects = { "network", "executes" }, reversible = true },
  timeout = 90000,
  run = function(args)
    local url = args.url
    if type(url) ~= "string" or not url:match("^https?://[^%s%c]+$") then
      return { content = "url must be an http or https URL with no spaces", error = { code = "invalid_arguments", message = "url must be an http or https URL with no spaces" } }
    end
    local reply = host.exec("bin/fiber-lightpanda", {
      "fetch",
      "--dump", "markdown",
      "--wait-until", "networkidle",
      "--terminate-ms", tostring(TERMINATE_MS),
      "--dump-max-bytes", tostring(DUMP_MAX_BYTES),
      "--block-private-networks",
      url,
    }, { env = { LIGHTPANDA_DISABLE_TELEMETRY = "true" } })
    if reply.exit_code ~= 0 then
      local why = "lightpanda exited " .. tostring(reply.exit_code or reply.signal) .. ": " .. reply.stderr:sub(1, 500)
      return { content = why, error = { code = "tool_error", message = why } }
    end
    if reply.stdout == "" then
      local why = "lightpanda rendered an empty page"
      return { content = why, error = { code = "tool_error", message = why } }
    end
    return reply.stdout
  end,
})
