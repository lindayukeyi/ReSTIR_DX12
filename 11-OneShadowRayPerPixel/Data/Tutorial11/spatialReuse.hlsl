/* Spatial Reuse */

// Include helper functions
// #include "diffusePlus1ShadowUtils.hlsli"
#include "pbr.hlsli"
#include "randomHelper.hlsli"

static const float PI = 3.14159265f;

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit to sample // w: distToLight
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

cbuffer MyCB
{
	uint gFrameCount; // Frame counter, used to perturb random seed each frame
};

struct Pingpong
{
	float4 preservoir        : SV_Target0;
	float4 ptoSample         : SV_Target1;
	float4 pemittedLight     : SV_Target2;
	int    pM                : SV_Target3;
};

void updatereservoir(float3 le, float4 tos, float w, inout uint seed, inout Pingpong pp) {
	pp.preservoir.y += w;  // wsum += w
	pp.pM = pp.pM + 1;
	if (pp.preservoir.y > 0 && nextRand(seed) < (w / pp.preservoir.y)) {
		pp.pemittedLight = float4(le, 1.f);
		pp.ptoSample = tos;
	}
	return;
}

Pingpong main(float2 texC : TEXCOORD, float4 pos : SV_Position)
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	float width;
	float height;
	reservoir.GetDimensions(width, height);
	
	int M_sum = 0;
	uint seed = initRand(pixelPos.x + pixelPos.y * width.x, gFrameCount, 16);
	Pingpong pp;

	pp.preservoir = reservoir[pixelPos];
	pp.ptoSample = float4(toSample[pixelPos].xyz * toSample[pixelPos].w + gWsPos[pixelPos].xyz, 1);
	pp.pemittedLight = emittedLight[pixelPos];
	pp.pM = M[pixelPos];

	if (gWsPos[pixelPos].w == 0) {
		float3 curToSample = pp.ptoSample.xyz - gWsPos[pixelPos].xyz;
		pp.ptoSample = float4(normalize(curToSample), length(curToSample));
		return pp;
	}
	
	// Sample k = 5 (k = 3 for our unbiased algorithm) random points in a 30 - pixel radius around the current pixel
	for (int i = 0; i < 5; i++) {
		float r = 10.0 * sqrt(nextRand(seed));
		float theta = 2.0 * PI * nextRand(seed);
		float2 neighborf = pos.xy;
		neighborf.x += r * cos(theta);
		neighborf.y += r * sin(theta);
		
		// If the pixel is out of bound, discard it
		if (neighborf.x < 0 || neighborf.x >= width || neighborf.y < 0 || neighborf.y >= height) {
			continue;
		}
		uint2 neighborPos = (uint2)neighborf;

		// TODO: comment this
		if (reservoir[neighborPos].x == 0) {
			continue;
		}

		// The angle between normals of the current pixel to the neighboring pixel exceeds 25 degree		
		if (dot(gWsNorm[pixelPos].xyz, gWsNorm[neighborPos].xyz) < 0.9063) {
			continue;
		}

		// Exceed 10% of current pixel's depth
		if (gWsNorm[neighborPos].w > 1.1 * gWsNorm[pixelPos].w || gWsNorm[neighborPos].w < 0.9 * gWsNorm[pixelPos].w) {
			continue;
		}

		float3 lightPosW = toSample[neighborPos].xyz * toSample[neighborPos].w + gWsPos[neighborPos].xyz;
		float3 curToSampleUnit = normalize(lightPosW - gWsPos[pixelPos].xyz);

		float p_hat = evalP(curToSampleUnit, gMatDif[pixelPos].xyz, emittedLight[neighborPos].xyz, gWsNorm[pixelPos].xyz);
		float4 toS = float4(lightPosW, 1);
		float w = p_hat * reservoir[neighborPos].x * M[neighborPos];
		updatereservoir(emittedLight[neighborPos].xyz, toS, w, seed, pp);

		M_sum += M[neighborPos];
	}

	pp.pM = M_sum + M[pixelPos];

	float3 curToSample = pp.ptoSample.xyz - gWsPos[pixelPos].xyz;
	pp.ptoSample = float4(normalize(curToSample), length(curToSample));
	float p_hat_s = evalP(pp.ptoSample.xyz, gMatDif[pixelPos].xyz, pp.pemittedLight.xyz, gWsNorm[pixelPos].xyz);

	if (p_hat_s == 0) {
		pp.preservoir.x = 0;
	}
	else {
		pp.preservoir.x = pp.preservoir.y / p_hat_s / float(pp.pM);
	}

	return pp;
}