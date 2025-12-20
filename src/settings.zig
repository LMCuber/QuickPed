pub const Settings = struct {
    width: i32 = 800,
    height: i32 = 800,
    fps_cap: i32 = 60,

    pub fn tabWidth(self: Settings) i32 {
        return @divFloor(self.width, 3);
    }
};
