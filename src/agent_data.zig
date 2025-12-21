pub const AgentData = struct {
    // lifetime
    num_to_place: i32 = 10,

    // properties
    speed: f32 = 2.0,
    relaxation: f32 = 10,
    radius: i32 = 8,
    a_ped: f32 = 0.08,
    b_ped: f32 = 4,
    show_vectors: bool = false,
};
