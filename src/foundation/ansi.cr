require "./sgr"

module Foundation
  # String Terminator for OSC sequences
  ST = "\e\\"

  # Closes any open hyperlink span, to be placed after the linked text.
  RESET_HYPERLINK = "\e]8;;\e\\"

  # Matches a single ANSI escape sequence: CSI, OSC (Operating System Command) with BEL (Bell) or ST (String Terminator), or two byte ESC.
  # No need for full parsing here, a regex is sufficient for stripping these.
  ESCAPE_PATTERN = /
      \e\[ [\x30-\x3F]* [\x20-\x2F]* [\x40-\x7E]  # CSI
      |
      \e\] .*? (?: \x07 | \e\\ )                  # OSC (terminated by BEL or ST)
      |
      \e [\x20-\x7E]                              # other two-byte ESC
    /x

  # Strips all ANSI escape sequences from *string*, leaving only printable content.
  def self.strip(string : String) : String
    string.gsub(ESCAPE_PATTERN, "")
  end

  # Opens a hyperlink span pointing to *url*.
  # Optional *params* are encoded as k=v pairs joined by ':'.
  #
  # Trust the caller. Caller is responsible for ensuring that *url*  is free of control characters.
  def self.set_hyperlink(url : String, **params) : String # ameba:disable Naming/AccessorMethodName
    param_str = params.empty? ? "" : params.map { |k, v| "#{k}=#{v}" }.join(':')
    "\e]8;#{param_str};#{url}\e\\"
  end
end
