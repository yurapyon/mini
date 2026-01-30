pub const c = @cImport({
    @cInclude("portaudio.h");
    @cInclude("emu8950.h");
    @cInclude("emuadpcm.h");
});
