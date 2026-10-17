"""Run: python -m unittest discover -s MeetingStoneEllesmereUI/tests -p test_walk.py -v
The descendant walk (every MainPanel / BrowsePanel / tab show) reads each frame's
children and regions once, and visits the same frames as before.
"""
import unittest
import test_regressions as regression

# Core.lua 1.4.22 (GitHub 6279f76): the walk this replaces, kept for comparison.
OLD_WALK = r'''
oldWalk = {}
function oldWalk.FontAll(frame)
    if not frame.GetRegions then return end
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("FontString") then
            ns.Safe(ns.Font, r)
        end
    end
end
function oldWalk.Walk(frame, depth)
    depth = depth or 0
    if not frame or depth > 10 then return end
    if type(frame) ~= "table" then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if ns.skip[frame] then return end
    ns.Safe(ns.SkinObject, frame)
    ns.Safe(oldWalk.FontAll, frame)
    if not frame.GetChildren then return end
    for i = 1, select("#", frame:GetChildren()) do
        oldWalk.Walk(select(i, frame:GetChildren()), depth + 1)
    end
end
'''

TREE = r'''
ns.skip = {}
mt = getmetatable(main)
function mt.IsObjectType(self, kind) return self.kind == kind end
-- A list-shaped tree: 12 rows x 4 cells, each cell with one decoration frame.
function buildTree()
    local root = CreateFrame('Frame'); root:CreateTexture(); root:CreateFontString()
    for i = 1, 12 do
        local row = CreateFrame('Button', nil, root); row:CreateTexture(); row:CreateFontString()
        for j = 1, 4 do
            local cell = CreateFrame('Button', nil, row); cell:CreateTexture(); cell:CreateFontString()
            CreateFrame('Frame', nil, cell):CreateTexture()
        end
    end
    return root
end
function measure(walk, root)
    local nativeChildren, nativeRegions = mt.GetChildren, mt.GetRegions
    local children, regions, visits, fonts = 0, 0, {}, 0
    mt.GetChildren = function(f) children = children + 1; return nativeChildren(f) end
    mt.GetRegions = function(f) regions = regions + 1; return nativeRegions(f) end
    ns.SkinObject = function(f) visits[#visits + 1] = f end
    ns.Font = function() fonts = fonts + 1 end
    walk(root)
    mt.GetChildren, mt.GetRegions = nativeChildren, nativeRegions
    return children, regions, visits, fonts
end
function count(f)
    local n = 1
    for _, c in ipairs({ mt.GetChildren(f) }) do n = n + count(c) end
    return n
end
'''


class WalkTests(unittest.TestCase):
    setUp = regression.RegressionTests.setUp
    run_lua = regression.RegressionTests.run_lua

    def load(self):
        core = (regression.ROOT / 'Core.lua').read_text(encoding='utf-8-sig')
        self.lua.execute('local ns=ns; ' + core[core.index('function ns.FontAll'):core.index('-- Mark an object as handled')])
        self.lua.execute('local ns=ns; ' + core[core.index('local MAX_DEPTH'):core.index('-- Re-walk a root')])
        self.lua.execute(OLD_WALK)
        self.lua.execute(TREE)

    def test_each_frame_is_read_once_and_the_same_frames_are_visited(self):
        self.load()
        new, old, frames = self.lua.execute('''
            local root = buildTree()
            local n = count(root)
            local c1, r1, v1, f1 = measure(ns.Walk, root)
            local c2, r2, v2, f2 = measure(oldWalk.Walk, root)
            assert(#v1 == n and #v2 == n, 'walk missed frames')
            for i = 1, n do assert(v1[i] == v2[i], 'visit order changed at '..i) end
            assert(f1 == f2 and f1 == 61, 'font strings: '..f1..' / '..f2)
            assert(c1 == n and r1 == n, ('reads: %d children, %d regions for %d frames'):format(c1, r1, n))
            return c1 + r1, c2 + r2, n
        ''')
        self.assertEqual((frames, new), (109, 218))
        self.assertGreater(old, new * 2, (old, new))

    def test_skip_and_depth_limit_still_stop_the_walk(self):
        self.load()
        self.run_lua('''
            local root = buildTree()
            local first = ({ mt.GetChildren(root) })[1]
            ns.skip[first] = true
            local _, _, visits = measure(ns.Walk, root)
            assert(#visits == count(root) - count(first), 'skipped subtree was walked')
            local deep, f = CreateFrame('Frame'), nil
            f = deep
            for i = 1, 15 do f = CreateFrame('Frame', nil, f) end
            local _, _, v = measure(ns.Walk, deep)
            assert(#v == 11, 'depth limit: '..#v)
        ''')


if __name__ == '__main__':
    unittest.main()
