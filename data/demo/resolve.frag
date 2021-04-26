#version 420 core

#extension GL_EXT_shader_samples_identical : require

layout(binding = 0) uniform sampler2DMS colorTexture;

uniform int samples;
uniform vec4 screenResolution;
uniform vec3 white_point;

uniform float exposure;

layout(location = 0) out vec4 o_FragColor;

void main(void)
{
    const ivec2 P = ivec2(gl_FragCoord.xy * textureSize(colorTexture) / screenResolution.xy);

    // Resolve MSAA samples
    vec4 color = texelFetch(colorTexture, P, 0);
    // Should reduce bandwidth (enabled on iris and radeonsi)
    if (!textureSamplesIdenticalEXT(colorTexture, P)) {
        for (int i = 1; i < samples; ++i) {
            vec4 c = texelFetch(colorTexture, P, i);
            color += vec4(c.a * c.rgb, c.a);
        }
    }

    if (color.a > 0.0) {
        color.rgb /= color.a;
    }

    // White balance
    color.rgb *= white_point;

    // Tone map
    color.rgb = vec3(1.0) - exp(-color.rgb * exposure);

    // Reinhard tonemapping
//    color.rgb *= exposure;
//    color.rgb /= 1.0 + color.rgb;

    // Gamma correction
    o_FragColor = vec4(pow(color.rgb, vec3(1.0 / 2.2)), 1.0);
}
