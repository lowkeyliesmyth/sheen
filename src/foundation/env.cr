module Foundation
  # Readonly lookup interface for environment variables.
  abstract struct Env
    abstract def []?(key : String) : String?
  end

  # Delegates []? to ENV[key]?
  struct LiveEnv < Env
    def []?(key : String) : String?
      ENV[key]?
    end
  end

  # Wraps a Hash(String, String), so `[]?` delegates to `h[key]?` in order to give specs a hermetic env without messing with real process env vars.
  struct MockEnv < Env
    getter h : Hash(String, String)

    def initialize(@h = {} of String => String)
    end

    def []?(key : String) : String?
      @h[key]?
    end

    def []=(key : String, value : String) : String
      @h[key] = value
    end
  end
end
