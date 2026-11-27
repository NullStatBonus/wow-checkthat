"""The result sounds the addon ships (#229): each one the code names is there, is a real Ogg Vorbis file, is short and small.
Reads the Ogg pages itself, so the test needs nothing beyond the standard library."""
import os, re, struct, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "CheckThat", "Media", "Sounds")


def ogg_vorbis_seconds(path):
    """Length in seconds from the Vorbis identification header's rate and the last page's granule position."""
    data = open(path, "rb").read()
    if data[:4] != b"OggS":
        raise ValueError("not an Ogg file")
    seg = data[26]
    body = 27 + seg
    head = data[body:body + 30]
    if head[1:7] != b"vorbis" or head[0] != 1:
        raise ValueError("not Vorbis")
    rate = struct.unpack("<I", head[12:16])[0]
    last = data.rfind(b"OggS")
    granule = struct.unpack("<q", data[last + 6:last + 14])[0]
    return granule / rate


class Sounds(unittest.TestCase):
    def names_in_code(self):
        with open(os.path.join(ROOT, "CheckThat", "UI", "Sound.lua"), encoding="utf-8") as fh:
            src = fh.read()
        block = re.search(r"Sound\.FILES = \{(.*?)\n\}", src, re.S)
        self.assertIsNotNone(block, "Sound.FILES not found in UI/Sound.lua")
        found = re.findall(r'(?:\["([\w-]+)"\]|\b(\w+))\s*=\s*"([\w-]+\.ogg)"', block.group(1))
        return [(a or b, f) for a, b, f in found]

    def test_every_sound_the_code_names_is_a_short_small_ogg_vorbis_file(self):
        names = self.names_in_code()
        self.assertEqual(sorted(n for n, _ in names), ["attention", "chime-down", "chime-up", "finish", "tick"])
        for name, fname in names:
            path = os.path.join(SOUNDS, fname)
            self.assertTrue(os.path.isfile(path), path)
            self.assertLess(os.path.getsize(path), 20 * 1024, fname)
            secs = ogg_vorbis_seconds(path)
            self.assertTrue(0.08 <= secs <= 0.45, "%s lasts %.3f s" % (fname, secs))

    def test_no_sound_file_is_left_unused(self):
        used = {f for _, f in self.names_in_code()}
        self.assertEqual(set(os.listdir(SOUNDS)), used)


if __name__ == "__main__":
    unittest.main()
