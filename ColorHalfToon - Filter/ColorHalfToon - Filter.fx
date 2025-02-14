/////////////////////////////////////////////////////////////////////////////////
// ColorHalfToon - Filter by Joshua
/////////////////////////////////////////////////////////////////////////////////
// Filter Color
float3 ColorShad = float3(0.0784313725490196,0.1294117647058824,0.2196078431372549);
	
/////////////////////////////////////////////////////////////////////////////////

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;


texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewportRatio = {1.0f, 1.0f};
	bool AntiAlias = true;
	int MipLevels = 1;
	string Format = "A16B16G16R16F";
>;

sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};

texture2D ColorHalfToneAlphaMask : OFFSCREENRENDERTARGET
<
    string Description = "Color Half Tone Alpha Mask RT";
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
	int Miplevels = 0;
	string DefaultEffect = "self = hide;"
	    "*= Resources/Alpha - On.fx;";
>;
sampler2D AlphaMaskSampler = sampler_state {
    texture = <ColorHalfToneAlphaMask>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
    MIPFILTER = LINEAR;
    ADDRESSU  = CLAMP;
    ADDRESSV  = CLAMP;
};
/////////////////////////////////////////////////////////////////////////////////
uniform int size = 520; // amount of dots
uniform float dot_size = 1.5; // dots are multiplied by dot_size
uniform float value_multiplier = 1; // reduce or increase value, useful when its too bright
uniform bool invert = false;
/////////////////////////////////////////////////////////////////////////////////
float Exposure    = 5.0;
float Saturation = 1.0;
float Gama = 1.0;
/////////////////////////////////////////////////////////////////////////////////
float2 yccLookup(float x)
{
    float v9 = 1.0;
    v9 *= 1 * Gama;
	v9 += 1;
	
    float samples = 32;
    float scale = 1.0 / samples;
    float i = x * 16 * samples;
    float v11 = exp( -i * scale );
    float v10 = pow( 1.0 - v11, v9 );
    v11 = v10 * 2.0 - 1.0;
    v11 *= v11;
    v11 *= v11;
    v11 *= v11;
    v11 *= v11;
	samples *= Saturation;
	
	
    return float2( v10, v10 * ( samples / i ) * ( 1.0 - v11 ) );
}

float3 ColorToneMapping( float3 c)
{
    float exposure = 1.0;
	
    exposure = 	lerp(exposure, Exposure, exposure);
	
    float4 color;
    color.rgb = c;

    color.y = dot( color.rgb, float3( 0.30, 0.59, 0.11 ) );
    color.rb -= color.y;
    color.yw = yccLookup( color.y * exposure * 0.0625 );
    color.rb *= exposure * color.w;
    color.w = dot( color.rgb, float3( -0.508475, 1.0, -0.186441 ) );
    color.rb += color.y;
    color.g = color.w;    
	return color.rgb;
}


/////////////////////////////////////////////////////////////////////////////////
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alphaM = MaterialDiffuse.a;
/////////////////////////////////////////////////////////////////////////////////
// HUE CODE

float3 RGBtoHSL(float3 color)
{
    float maxC = max(color.r, max(color.g, color.b));
    float minC = min(color.r, min(color.g, color.b));
    float delta = maxC - minC;
    
    float h = 0.0;
    float s = 0.0;
    float l = (maxC + minC) * 0.5;

    if (delta > 0.0001)
    {
        s = (l < 0.5) ? (delta / (maxC + minC)) : (delta / (2.0 - maxC - minC));

        if (maxC == color.r)
            h = (color.g - color.b) / delta + (color.g < color.b ? 6.0 : 0.0);
        else if (maxC == color.g)
            h = (color.b - color.r) / delta + 2.0;
        else
            h = (color.r - color.g) / delta + 4.0;

        h /= 6.0;
    }

    return float3(h, s, l);
}

// Convert HSL back to RGB
float3 HSLtoRGB(float3 hsl)
{
    float3 rgb;

    float q = (hsl.z < 0.5) ? (hsl.z * (1.0 + hsl.y)) : (hsl.z + hsl.y - hsl.z * hsl.y);
    float p = 2.0 * hsl.z - q;

    float3 t = float3(hsl.x + 1.0 / 3.0, hsl.x, hsl.x - 1.0 / 3.0);
    
    for (int i = 0; i < 3; i++)
    {
        if (t[i] < 0.0) t[i] += 1.0;
        if (t[i] > 1.0) t[i] -= 1.0;

        if (t[i] < 1.0 / 6.0)
            rgb[i] = p + (q - p) * 6.0 * t[i];
        else if (t[i] < 1.0 / 2.0)
            rgb[i] = q;
        else if (t[i] < 2.0 / 3.0)
            rgb[i] = p + (q - p) * (2.0 / 3.0 - t[i]) * 6.0;
        else
            rgb[i] = p;
    }

    return rgb;
}

/////////////////////////////////////////////////////////////////////////////////
//Vertex Shader
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
    float4 PPos			: TEXCOORD2;
    float4 RTPos		: TEXCOORD3;
};

VS_OUTPUT SceneVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0,float4 PPos : TEXCOORD1)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	Out.PPos = Out.Pos;
	
	return Out;
}

///////////////////////////////////////////////////////////////////////////////////
float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
///////////////////////////////////////////////////////////////////////////////////
//Pixel Shader

float4 ScenePS(VS_OUTPUT IN) : COLOR0
{ 

	//AlphaMask
	float2 RTPos1;
    RTPos1.x				= (IN.PPos.x / IN.PPos.w)*0.5+0.5;
	RTPos1.y				= (-IN.PPos.y / IN.PPos.w)*0.5+0.5;
    float4 AlphaMask = tex2D(AlphaMaskSampler, RTPos1);
	
	//ColoHalfTone
	float fSize = size; 
	float2 ratio = float2(1.0, ViewportSize.x / ViewportSize.y);
	float2 pixelated_uv = floor(IN.Tex * fSize * ratio) / (fSize * ratio);
	float dots = length((IN.Tex * fSize * ratio) - floor(IN.Tex * fSize * ratio) - float2(0.5, 0.5)) * dot_size;
	float value = rgb2hsv(tex2D(ScnSamp, pixelated_uv).rgb).z;
	dots = lerp(dots, 1.0 - dots, float(invert));
	dots += value * value_multiplier;
	dots = pow(dots, 5.0);
	dots = clamp(dots, 0.0, 1.0);
	//
	
    float4 scene = tex2D(ScnSamp,IN.Tex);
    float4 sceneB = tex2D(ScnSamp,IN.Tex);
	
	scene.rgb = scene.rgb;
	float Alpha = 1;
	
	
	float3 sceneStep = step( 0.5 , scene) ? 1 : 0;
	
	scene.rgb	= lerp(scene,sceneStep,AlphaMask * alphaM);
	
	float sceneTC = (scene.r+scene.g+scene.b)/3;
	float4 sceneC = float4(sceneTC,sceneTC,sceneTC,scene.a);
		
	scene = lerp(sceneC, sceneTC, scene.a * 0.0);
	
	float3 scene_tone		= ColorToneMapping(scene.rgb);
	scene.rgb	= lerp(scene.rgb,scene_tone,AlphaMask * alphaM);
	
	scene.rgb	= lerp(scene.rgb,scene.rgb * sceneB,AlphaMask * alphaM);
	scene.rgb	= lerp(scene.rgb,sceneB,(1 - AlphaMask * alphaM));
	scene.rgb	= lerp(scene.rgb,scene.rgb * float3(dots,dots,dots),AlphaMask * alphaM);
	scene.rgb	= lerp(scene.rgb,scene.rgb + ColorShad.rgb, AlphaMask * alphaM);
	
	
	//HUE
    // Convert to HSL
    float3 hsl = RGBtoHSL(scene);

    // Shift Hue
    hsl.x += 1.0;
    if (hsl.x > 1.0) hsl.x -= 1.0;
    if (hsl.x < 0.0) hsl.x += 1.0;

    // Convert back to RGB
    float3 finalColor = HSLtoRGB(hsl);
	
	scene.rgb = finalColor;
    return scene;
}

/////////////////////////////////////////////////////////////////////////////////
technique RTT <
	string Script = 
		
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=RT;"
		;
	
> {
	pass RT < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SceneVS();
        PixelShader = compile ps_3_0 ScenePS();
	}
}
/////////////////////////////////////////////////////////////////////////////////
