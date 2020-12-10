/* Shade pixel */

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit point(ref) to sample // w: distToLight
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

// The texture containing our environment map
Texture2D<float4>   gEnvMap;

// Some early DXR drivers had a bug breaking atan2() in DXR shaders.  This is a work-around
float atan2_WAR(float y, float x)
{
	const float M_PI = 3.14159265358979323846;
	if (x > 0.f)
		return atan(y / x);
	else if (x < 0.f && y >= 0.f)
		return atan(y / x) + M_PI;
	else if (x < 0.f && y < 0.f)
		return atan(y / x) - M_PI;
	else if (x == 0.f && y > 0.f)
		return M_PI / 2.f;
	else if (x == 0.f && y < 0.f)
		return -M_PI / 2.f;
	return 0.f; // x==0 && y==0 (undefined)
}

// Convert our world space direction to a (u,v) coord in a latitude-longitude spherical map
float2 wsVectorToLatLong(float3 dir)
{
	const float M_1_PI = 0.3183099f;
	float u = (1.f + atan2_WAR(dir.x, -dir.z) * M_1_PI) * 0.5f;
	float v = acos(dir.y) * M_1_PI;
	return float2(u, v);
}

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position) : SV_Target0
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	if (gWsPos[pixelPos].w == 0) {
		float2 dims;
		gEnvMap.GetDimensions(dims.x, dims.y);
		float2 uv = wsVectorToLatLong(gMatDif[pixelPos].xyz);
		return float4(gEnvMap[uint2(uv * dims)].rgb, 1);
	}

	float lambert = max(0, dot(toSample[pixelPos].xyz, gWsNorm[pixelPos].xyz));
	float3 bsdf = gMatDif[pixelPos].xyz / 3.14159265359f;
	float3 L = emittedLight[pixelPos].xyz;
	
	// Compute pdf of sampling area light
	/*float pdfL = 0.f;
	float cosLight = dot(-toSample[pixelPos].xyz, sampleNormalArea[pixelPos].xyz);
	if (cosLight != 0.f && sampleNormalArea[pixelPos].w > 0) {
		float r = toSample[pixelPos].w;
		pdfL = r * r / (cosLight * sampleNormalArea[pixelPos].w);
	}*/

	return float4(bsdf * L * lambert * reservoir[pixelPos].x, 1);
}
