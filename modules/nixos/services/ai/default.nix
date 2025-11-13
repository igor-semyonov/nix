{
  pkgs,
  lib,
  types,
  config,
  ...
}: let
  cfg = config.mine.ai;
in {
  options.mine.ai = {
    ollama = {
      enable = lib.mkEnableOption;
    };
    open-webui = {
      enable = lib.mkEnableOption;
    };
  };
  config.services.ollama =
    lib.mkIf cfg.ollama.enable
    {
      enable = true;
      models = "/mnt/ollama-models";
      openFirewall = true;
      host = "0.0.0.0";
      port = 11434;
    };
  config.services.open-webui = lib.mkIf cfg.open-webui.enable {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
    port = 11435;
    environment = let
      t = "True";
      f = "False";
    in {
      ANONYMIZED_TELEMETRY = f;
      DO_NOT_TRACK = t;
      SCARF_NO_ANALYTICS = t;
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";

      ENABLE_SIGNUP = t;
      DEFAULT_USER_ROLE = "pending";
      DEFAULT_LOCALE = "en";
      ENABLE_CHANNELS = t;
      THREAD_POOL_SIZE = "64";
      MODELS_CACHE_TTL = "0";
      ENABLE_REALTIME_CHAT_SAVE = t;
      BYPASS_MODEL_ACCESS_CONTROL = t;
      ENABLE_TITLE_GENERATION = t;
      DEFAULT_PROMPT_SUGGESTIONS = ''
        [
          {
            "title": [
              "Title part 1",
              "Title part 2"
            ],
            "content": "prompt"
          }
        ]'';
    };
  };
}
