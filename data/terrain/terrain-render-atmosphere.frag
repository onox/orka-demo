#ifdef USE_LUMINANCE
#define GetSkyRadianceToPoint GetSkyLuminanceToPoint
#define GetSunAndSkyIrradiance GetSunAndSkyIlluminance
#endif

vec3 GetSkyRadianceToPoint(vec3 camera, vec3 point, float shadow_length,
    vec3 sun_direction, out vec3 transmittance);
vec3 GetSunAndSkyIrradiance(
    vec3 p, vec3 normal, vec3 sun_direction, out vec3 sky_irradiance);

uniform vec4 camera_pos;
uniform vec4 sun_direction;
uniform float earth_radius;

layout(binding = 4) uniform sampler2D u_DmapSampler;
layout(binding = 5) uniform sampler2D u_SmapSampler;

uniform float u_DmapFactor;
uniform int u_LebID;
uniform bool u_UseSmap = true;

layout(std430, binding = 3) readonly restrict buffer ModelMatrixBuffer {
    mat4 modelMatrix[];
};

const float RPI = 1.0 / 3.141592653589793;

const vec3 terrain_color = vec3(0.0, 0.0, 0.04);

mat3 get_rotation_matrix(const vec3 a, const vec3 b)
{
    const vec3 v = cross(a, b);
    const float c = dot(a, b);

    const vec3 va = vec3( 0.0,  v.z, -v.y);
    const vec3 vb = vec3(-v.z,  0.0,  v.x);
    const vec3 vc = vec3( v.y, -v.x,  0.0);
    const mat3 vx = mat3(va, vb, vc);

    return mat3(1.0) + vx + vx * vx * (1.0 / (1.0 + c));
}

vec4 ShadeFragment(vec2 texCoord, vec4 worldPos)
{
    vec3 camera = camera_pos.xyz;
    vec3 point = worldPos.xyz;

    const mat4 worldM = modelMatrix[u_LebID];

    const float height = u_DmapFactor * texture(u_DmapSampler, texCoord).r;
    vec2 smap;

    if (u_UseSmap) {
        smap = u_DmapFactor * texture(u_SmapSampler, texCoord).rg;
    } else {
        const vec2 size = textureSize(u_DmapSampler, 0);

        const vec4 z = textureGather(u_DmapSampler, texCoord);
        const float r = (z.y + z.z) / 2.0;
        const float l = (z.x + z.w) / 2.0;
        const float t = (z.x + z.y) / 2.0;
        const float b = (z.w + z.z) / 2.0;
        smap = vec2(
            size.x * 0.5 * (r - l),
            size.y * 0.5 * (t - b)
        );
    }

    // The precomputed atmospheric scattering assumes a perfect sphere
    // with no flattening, adjust the camera and terrain to the assumed
    // radius
    const vec3 pointNormal = normalize(point);
    const vec3 pointOffset = ((length(point) - height) - earth_radius) * pointNormal;

    point  -= pointOffset;
    camera -= pointOffset;

    const vec4 terrainNormal = worldM * vec4(normalize(vec3(1.0, -smap)), 1.0);
    const vec4 terrainUp = worldM * vec4(1.0, 0.0, 0.0, 0.0);

    // Additional rotation from center of tile to point
    const mat3 R = get_rotation_matrix(terrainUp.xyz, pointNormal);
    const vec3 newPointNormal = R * terrainNormal.xyz;

    // Compute the radiance reflected by the ground
    vec3 skyIrradiance;
    vec3 sunIrradiance = GetSunAndSkyIrradiance(
        point, newPointNormal, sun_direction.xyz, skyIrradiance);
    vec3 groundRadiance = terrain_color * RPI * (sunIrradiance + skyIrradiance);
    // sun_irradiance can be modulated by sun visibility factor based on point and sun direction
    // sky_irradiance can be modulated by sky visibility factor based on point

    float shadowLength = 0.0;

    vec3 transmittance;
    vec3 inScatter = GetSkyRadianceToPoint(camera,
        point, shadowLength, sun_direction.xyz, transmittance);
    groundRadiance = groundRadiance * transmittance + inScatter;

    return vec4(groundRadiance, 1.0);
}
