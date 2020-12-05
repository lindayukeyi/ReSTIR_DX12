/* Physically based rendering */

// toLight, lightNormal and normal should be normalized before calling this function
//float evalP(float3 toLight, float3 lightNormal, float distToLight, float area, float3 nor) {
//	float lambert = saturate(dot(toLight, nor));
//	float brdf = 1.f / 3.1415926535898f;
//	float geom_term = distToLight * distToLight / (saturate(abs(dot(toLight, lightNormal))) * area);
//	float p = lambert * brdf / geom_term;
//	return p;
//}

// energy uses radiance as unit, such that for point lights it is already divided by squaredDistance.
float evalP(float3 toLight, float3 diffuse, float3 energy, float3 nor) {
	float lambert = saturate(dot(toLight, nor));
	float3 brdf = diffuse / 3.1415926535898f;
	float3 color = brdf * energy * lambert;
	return length(color);
}

// Debug
bool equals(float4 a, float4 b) {
	return (a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w);
}

bool equals(float3 a, float3 b) {
	return (a.x == b.x && a.y == b.y && a.z == b.z);
}


bool equal(float4 a, float4 b) {
	return (abs(a.x - b.x) < 0.001) &&
		(abs(a.y - b.y) < 0.001) &&
		(abs(a.z - b.z) < 0.001) &&
		(abs(a.w - b.w) < 0.001);
}

bool equal(float3 a, float3 b) {
	return (abs(a.x - b.x) < 0.001) &&
		(abs(a.y - b.y) < 0.001) &&
		(abs(a.z - b.z) < 0.001);
}