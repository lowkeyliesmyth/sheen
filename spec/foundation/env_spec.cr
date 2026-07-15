require "../spec_helper"

describe Foundation::Env do
  describe Foundation::MockEnv do
    it "returns the value for a set key" do
      env = Foundation::MockEnv.new({"COLORFGBG" => "15;0"})
      env["COLORFGBG"]?.should eq("15;0")
    end

    it "returns nil for an absent key" do
      env = Foundation::MockEnv.new({} of String => String)
      env["COLORFGBG"]?.should be_nil
    end
  end

  describe Foundation::LiveEnv do
    # set and clean up a throwaway probe var since LiveEnv is a thin delegate over real ENV
    it "delegates reads to ENV and returns nil for unset keys" do
      key = "__SHEEN_ENV_SPEC_PROBE__"
      ENV[key] = "live"
      begin
        Foundation::LiveEnv.new[key]?.should eq("live")
        Foundation::LiveEnv.new["__NO_SUCH_VAR__"]?.should be_nil
      ensure
        ENV.delete(key)
      end
    end
  end
end
