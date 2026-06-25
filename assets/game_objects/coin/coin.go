components {
  id: "coin"
  component: "/assets/game_objects/coin/coin.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"coin\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/game_objects/coin/coin.atlas\"\n"
  "}\n"
  ""
  scale {
    x: 0.75
    y: 0.75
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"coin\"\n"
  "mask: \"default\"\n"
  "mask: \"body\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "  }\n"
  "  data: 24.0\n"
  "}\n"
  "event_collision: false\n"
  "event_contact: false\n"
  ""
}
