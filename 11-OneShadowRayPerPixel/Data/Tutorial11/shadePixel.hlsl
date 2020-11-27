/* Shade pixel */

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

// Reservoir texture
RWTexture2D<int> sampleIndex;
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit to sample // w: distToLight
RWTexture2D<float4> sampleNormalArea; // xyz: sample noraml // w: area of light
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

cbuffer MyConst {
	uint lightCount;
}

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position) : SV_Target0
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?

	float lambert = max(0, dot(toSample[pixelPos].xyz, gWsNorm[pixelPos].xyz));
	float3 bsdf = gMatDif[pixelPos].xyz / 3.14159265359f;
	float3 L = emittedLight[pixelPos].xyz;
	
	// Compute pdf of sampling light
	float pdfL = 0.f;
	float cosLight = dot(-toSample[pixelPos].xyz, sampleNormalArea[pixelPos].xyz);
	if (cosLight != 0.f && sampleNormalArea[pixelPos].w > 0) {
		float r = toSample[pixelPos].w;
		pdfL = r * r / (cosLight * sampleNormalArea[pixelPos].w);
	}
	if (pdfL == 0.f) {
		return float4(0, 0, 0, 1.f);
	}
	else {
		float3 ret = (bsdf * L) * lambert * lightCount / pdfL * reservoir[pixelPos].x;
		return float4(ret, 1.f);
	}
	return float4(0, 0, 0, 1);
}
