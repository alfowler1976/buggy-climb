#version 140

in mediump vec2 var_texcoord0;

out vec4 out_fragColor;

uniform mediump sampler2D texture_sampler;
uniform fs_uniforms
{
    mediump vec4 tint;
    mediump vec4 offset;
};

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    mediump vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);

    mediump vec2 tex_pos = fract(var_texcoord0.xy + offset.xy);
    out_fragColor = texture(texture_sampler, tex_pos) * tint_pm;
}
