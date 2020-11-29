/* Physically based rendering */

// toLight, lightNormal and normal should be normalized before calling this function
float evalP(float3 toLight, float3 lightNormal, float distToLight, float area, float3 nor) {
	float lambert = saturate(dot(toLight, nor));
	float brdf = 1.f / 3.1415926535898f;
	float geom_term = distToLight * distToLight / (saturate(abs(dot(toLight, lightNormal))) * area);
	float p = lambert * brdf / geom_term;
	return p;
}