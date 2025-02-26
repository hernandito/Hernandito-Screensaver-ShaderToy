// Simple 2D Planet shader 

// inspired by differnet planet shaders out there. This on specifically is used in my project in GODOT.
// adapted here by using a FBM noise function as the main texture.


// planet constants
#define PLANET_SIZE 0.9
#define SMOOTH_EDGE_SIZE 0.02
#define ATMOSPHERE_THICKNESS 0.01
#define ROTATION_SPEED 0.03

// noise constants 
#define FBM_OCTAVES 7
#define FBM_AMPLITUDE 1.0
#define FBM_FALL_OFF 0.7
#define FBM_FREQUENCY 2.0


vec2 offset = vec2(0.5,0.5);
float scale = 1.0;
vec2 light_origin = vec2(-0.1, 0.1);
vec4 planet_color = vec4(1.0 , 0.34, 0.0, 1.0);
vec4 atmosphere_color = vec4(0.41, 0.6, 1.0, 1.0);
float light_shadow_hardness = 0.5;
vec4 light_color = vec4(1.0);
float light_size = 2.0;
float light_intensity = 0.9;
float shadow_size = 1.8;
float shadow_intensity = 1.0;
float rotation_axis = -0.2;




// Noise functions
// helper functions used for simplex noise algorithm
vec3 mod289_v3(vec3 x) { 
	return x - floor(x * (1.0 / 289.0)) * 289.0; 
	}
vec2 mod289_v2(vec2 x) { 
	return x - floor(x * (1.0 / 289.0)) * 289.0; 
	}
vec3 permute(vec3 x) { 
	return mod289_v3(((x*34.0)+1.0)*x); 
}
// simplex noise function taken from https://thebookofshaders.com/edit.php#11/2d-snoise-clear.frag
float simplex_noise(vec2 v) {
	// Precompute values for skewed triangular grid
    const vec4 C = vec4(0.211324865405187,
                        // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,
                        // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,
                        // -1.0 + 2.0 * C.x
                        0.024390243902439);
                        // 1.0 / 41.0

    // First corner (x0)
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    vec2 i1 = vec2(0.0);
    i1 = (x0.x > x0.y)? vec2(1.0, 0.0):vec2(0.0, 1.0);
    vec2 x1 = x0.xy + C.xx - i1;
    vec2 x2 = x0.xy + C.zz;

    // Do some permutations to avoid
    // truncation effects in permutation
    i = mod289_v2(i);

    vec3 p = permute(
            permute( i.y + vec3(0.0, i1.y, 1.0))
                + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2)
                        ), 0.0);

    m = m*m ;
    m = m*m ;

    // Gradients:
    //  41 pts uniformly over a line, mapped onto a diamond
    //  The ring size 17*17 = 289 is close to a multiple
    //      of 41 (41*7 = 287)
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt(a0*a0 + h*h);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

    // Compute final noise value at P
    vec3 g = vec3(0.0);
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * vec2(x1.x,x2.x) + h.yz * vec2(x1.y,x2.y);
    return 130.0 * dot(m, g);
}


// from book of shaders https://thebookofshaders.com/13/
float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = FBM_AMPLITUDE;
	float fall_off = FBM_FALL_OFF;
    float frequency = FBM_FREQUENCY;
    //
    // Loop of octaves
    for (int i = 0; i < FBM_OCTAVES; i++) {
        value += amplitude * simplex_noise(st);
        st *= frequency;
        amplitude *= fall_off;
        //frequency *= fall_off;
    }
    return value;
}




// spherify, taken from the Spherify shader here: https://www.shadertoy.com/view/MlycWw 
vec2 spherify(vec2 uv) {

    // centre
    uv -= 0.5;
    uv *= 2.0;
    
    float r = length(uv * 1.0/PLANET_SIZE);
    uv *= asin(r)/(r * sqrt(2.0));
    return uv; 
}



// Utility function to rotate coordinates
vec2 rotate(vec2 coord, float angle) {
    coord -= 0.5;
    coord *= mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
    return coord + 0.5;
}





void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    
    // screen UV with correct aspect ratio, the apply some general UV offset and scaling
    vec2 uv = fragCoord/iResolution.xy;
    vec2 ratio = vec2(iResolution.x/iResolution.y, 1.0);
    uv = (uv - 0.5) * ratio;
    uv = uv * (2.0 - PLANET_SIZE) - (1.0 - PLANET_SIZE) * 0.5;
    uv *= scale;
    uv += offset;
    
    // Spherify UV and apply rotation
    vec2 spheric_uv = spherify(uv);
    float directional_light = distance(spheric_uv, light_origin);
    
    // Create planet shape
    float dist = length(uv - vec2(0.5));
    float planet_shape = smoothstep(0.46 * PLANET_SIZE, 
                                  0.459 * PLANET_SIZE - SMOOTH_EDGE_SIZE, 
                                  dist);
    
    // Shadow and light masks
    float shadow_shape = smoothstep(0.46 * shadow_size, 
                                  0.459 * light_shadow_hardness * shadow_size, 
                                  length(uv - light_origin));
    float light_shape = smoothstep(0.46 * light_size, 
                                 0.459 * light_shadow_hardness * light_size, 
                                 length(uv + light_origin - vec2(1.0)));
    
    // create Atmosphere
    float atmosphere_shape = smoothstep(0.46 * PLANET_SIZE + ATMOSPHERE_THICKNESS, 
                                      0.459 * PLANET_SIZE, 
                                      dist);
                                      
                                   
    atmosphere_shape *= 1.0 - planet_shape;// substract the planet shape of the atmosphere, leave an outline
    atmosphere_shape *= 1.0 - shadow_shape * shadow_intensity; // substract the shadow to darken the atmosphere locally
    atmosphere_shape *= 1.0 + light_shape * light_intensity; // add the light to lighten the atmosphere locally
    
    // create surface texture using a noise function
    vec2 spheric_uv_surface = rotate(spheric_uv, rotation_axis);
    spheric_uv_surface += vec2(iTime * ROTATION_SPEED, 0.0);
    vec4 color = vec4(planet_color.rgb * fbm(spheric_uv_surface),1.0);
 
    
    // Apply simple Lighting and shadow to shade the surface color
    color.rgb += light_shape * light_intensity * light_color.rgb;
    color = clamp(color, 0.0, 1.0); // adjust for overexposure
    color.rgb -= shadow_shape * shadow_intensity;
    
    
    // Apply planet shape to shaded surface color
    color *= planet_shape;
    
    // Apply Atmosphere outline
    color += atmosphere_color * atmosphere_shape;
    

    // output
    fragColor = color;
}