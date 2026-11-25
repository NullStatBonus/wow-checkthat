-- What a tester does in plans/checkthat-0.17.yaml where a plain Pass is not enough.
return {
    verdict = { ["ct17.partial"] = "partial", ["ct17.skip"] = "skip", ["ct17.fail"] = "fail" },
    action = {
        -- Click Land here in the Categories window, press > to come back, then Pass.
        ["ct17.click"] = function(R)
            assert(R.App.ShowStep("ct17.land"))
            R.App.Goto(1)
            R.App.Begin()
            R.press()
        end,
        -- Undo shows Reopen me. Pass it, the card comes back to this step. Pass here.
        ["ct17.undo"] = function(R)
            assert(R.App.Undo())
            R.App.Begin(); R.press()
            R.App.Begin(); R.press()
        end,
        -- Remove the Spare category from its row menu.
        ["ct17.remove"] = function(R)
            assert(R.App.Deselect("spare"))
            R.press()
        end,
    },
}
