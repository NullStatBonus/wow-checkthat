-- What a tester does in plans/checkthat-0.20.1.yaml where a plain Pass is not enough.
return {
    action = {
        -- Undo shows Pass me. Pass it, the card comes back to this step. Pass here.
        ["ct2001.undo"] = function(R)
            assert(R.App.Undo())
            R.App.Begin(); R.press()
            R.App.Begin(); R.press()
        end,
        -- /ct macrorun for a step that is not on the card, then Pass.
        ["ct2001.stale"] = function(R)
            local say = R.App.MacroRun("ct2001.nowhere")
            assert(say and say:find("ct2001.stale", 1, true), "chat names the step on the card")
            R.press()
        end,
        -- Back to the finished step, /ct fail is refused, forward again, Pass.
        ["ct2001.refuse"] = function(R)
            R.App.Goto(-1)
            local a, err = R.App.Verdict("fail")
            assert(a == nil and err and err:find("has a result", 1, true), "the slash result is refused")
            R.App.Goto(1)
            R.press()
        end,
    },
}
