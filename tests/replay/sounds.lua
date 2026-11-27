-- What a tester does in plans/sounds.yaml where a plain Pass is not enough. The replay plays the model only (no card), so
-- it checks the plan's flow; tests/test_sound.lua checks which sound each result plays.
return {
    verdict = { ["snd.partial"] = "partial", ["snd.failpress"] = "fail" },
    action = {
        -- Run reports hit twice at once: the count goes over and CheckThat records Fail by itself.
        ["snd.fail"] = function(R)
            R.ns.Slash.Run("selftest facts", {})
            local a = R.App.AutoSettle()
            assert(a and a.verdict == "fail", "the step fails at once")
        end,
        -- The fact never comes; after the attention sound at the time limit the tester presses Skip.
        ["snd.timeout"] = function(R)
            local a = R.press("skip")
            assert(a and a.verdict == "skip")
        end,
        -- Pass without the evidence is unverified (attention); then Skip.
        ["snd.nopass"] = function(R)
            local a = R.press("pass")
            assert(a and a.verdict == "unverified", "Pass without the evidence is unverified")
            R.App.Begin() -- the card opens the next attempt of the step it still shows
            a = R.press("skip")
            assert(a and a.verdict == "skip")
        end,
        -- Run turns sounds off and reports the fact; CheckThat passes the step by itself.
        ["snd.off"] = function(R)
            R.ns.Slash.Run("set card.sound off", {})
            R.ns.Slash.Run("fact", {})
            local a = R.App.AutoSettle()
            assert(a and a.verdict == "pass")
            assert(R.ns.Settings.Get("card.sound") == false)
        end,
        -- Run turns sounds on again, then Pass.
        ["snd.silent"] = function(R)
            R.ns.Slash.Run("set card.sound on", {})
            assert(R.ns.Settings.Get("card.sound") == true)
            assert(R.press())
        end,
    },
}
