

Shader "Unlit/CelRender"
{
    Properties
    {
        _MainTex("MainTex", 2D) = "white" {}
        _MainColor("Main Color", Color) = (1,1,1)
        _BumpMap("Normal Map",2D) = "bump" {}
        _BumpScale("Bump Scale",Range(0,1)) = 0.5
            [Space(20)]
        _ShadowColor("Shadow Color", Color) = (0.7, 0.7, 0.8)
        _ShadowRange("Shadow Range", Range(0, 1)) = 0.5
        _ShadowSmooth("Shadow Smooth", Range(0, 1)) = 0.2
         
         [Space(20)]
        _SpecularColor("Specular Color", Color) = (1,1,1)
        _SpecularRange("Specular Range",  Range(0, 1)) = 0.9
        _SpecularMulti("Specular Multi", Range(0, 1)) = 0.4
        _SpecularGloss("Sprecular Gloss", Range(0.001, 255)) = 4

        [Space(20)]
        _OutlineWidth("Outline Width", Range(0.01, 2)) = 0.24
        _OutLineColor("OutLine Color", Color) = (0.5,0.5,0.5,1)
         [Space(20)]
        _RimColor("Rim Color",Color) = (255,255,255,0)
        _RimRange("Rim Range",Range(0,1)) = 0.5
     
    }
      SubShader
    {
        Tags { "RenderType" = "Opaque" }

        pass
        {
           Tags {"LightMode" = "ForwardBase"}

            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            half3 _MainColor;

            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;


            half3 _ShadowColor;
            half _ShadowRange;
            half _ShadowSmooth;


            half3 _SpecularColor;
            half _SpecularRange;
            half _SpecularMulti;
            half _SpecularGloss;

            float4 _RimColor;
            float _RimRange;
           
          
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;//顶点的法线
                float2 uv : TEXCOORD0;//主纹理和法线纹理共用同一个uv
                float3 tangent:TANGENT;//切线空间
                
            };

            struct v2f
            { 
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD1;//xy存储主纹理的缩放平移数据,zw存储法线纹理的
               // float3 worldNormal : TEXCOORD1;//模型的世界法线
                //float3 worldPos : TEXCOORD2;
                float4 MatrixRow1:TEXCOORD2;//用于传递转换矩阵
                float4 MatrixRow2:TEXCOORD3;
                float4 MatrixRow3:TEXCOORD4;

             
            };


            v2f vert(a2v v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
               //o.uv = TRANSFORM_TEX(v.uv, _MainTex);//将顶点就行缩放和平移确保和材质里的uv坐标对应
                o.uv.xy = v.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.uv.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
                /*o.worldNormal = UnityObjectToWorldNormal(v.normal);//法线一起转换到世界坐标系
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;//将模型顶点坐标转换到世界坐标系
                o.pos = UnityObjectToClipPos(v.vertex);//转换到裁剪空间/*/
                //世界空间下的切线
                //O.worldTangent = mul((float3x3)_ObjectToWorld, v.tangent.xyz);
                //用于计算转换矩阵
               // o.worldBinormal = corss(o.worldNormal, o.worldTangent) * v.tangent.w;
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                float3 worldNormal = mul((float3x3)unity_ObjectToWorld, v.normal);
                float3 worldTangent = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
                float3 worldBinormal = corss(worldNormal, worldTangent) * v.tangent.w;
                o.MatrixRow1 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.MatrixRow2 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.MatrixRow3 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                return o;
            }
        

            half4 frag(v2f i) : SV_TARGET
            {
                half4 col = 1;
                float3 worldPos = float3(i.MatrixRow1.w, i.MatrixRow2.w, i.MatrixRow3.w);
                fixed3 bump = UnpackNormal(tex2D(_BumpTex, i.uv.zw));
                bump.xy *= _BumpScale;//将纹理坐标（二维）与缩放值相乘，此时法线还在切线空间下
                bump.z = sqrt(1 - max(0, dot(bump.xy, bum.xy)));//切线空间下的法线纹理贴图的法线高度

                //开始将切线空间转换到世界空间,搜的数学公式
                bump = float3(dot(i.MatrixRow1.xyz, bump),dot(i.MatrixRow2.xyz,bump),dot(i.MatrixRow3.xyz,bump));
                bump = normalize(bump);//只取法线向量
                // float3 worldNormal = normalize(float3(i.MatrixRow1.z, i.MatrixRow2.z, i.MatrixRow3.z));
                 half4 mainTex = tex2D(_MainTex, i.uv.xy);//解uv贴纹理
                 half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz);//视野方向，因为只取方向，所以要归一化
                 //half3 worldNormal = normalize(worldNormal);
                 half3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);



                 half halfLambert = dot(bump, worldLightDir) * 0.5 + 0.5;
                 // half3 diffuse = halfLambert > _ShadowRange ? _MainColor : _ShadowColor; 
                  //上面的用来计算漫反射的是一个二分判断，如果说大于我们设定的一个值，那么就当作受光面渲染，反之则是阴影面
                  half ramp = smoothstep(0, _ShadowSmooth, halfLambert - _ShadowRange);
                  //smootstep函数用于生成在定义域[0,_ShadowSmooth]上的一个值域为[0,1]的单调的连续函数，halfLambert - _ShadowRange为自变量
                  half3 diffuse = lerp(_ShadowColor, _MainColor, ramp);
                  //lerp函数用于将_ShadowColor, _MainColor进行插值，其比重为ramp
                  diffuse *= mainTex.rgb;
                  //颜色=环境光+漫反射

                  //高光计算

                  //获得反射的光源方向
                  fixed3 refDir = normalize(reflect(-_WorldSpaceLightPos0.xyz, bump));
                  half3 specular = _SpecularColor.rgb * pow(max(0, dot(viewDir, refDir)), _SpecularGloss);

                  //边缘光计算
                  half f = 1.0 - saturate(dot(viewDir, bump));

                  half3 rimColor = f * _RimColor.rgb * _RimColor.a;
                  col.rgb = (diffuse + specular + rimColor * _RimRange) * _LightColor0.rgb;



                  //光源颜色*漫反射
                  return col;
            
            }
            ENDCG
        }
        //这个pass通道是描边的
        Pass
       {
           Tags {"LightMode" = "ForwardBase"}

            Cull Front//剔除前面

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            half _OutlineWidth;
            half4 _OutLineColor;

             struct a2v
             {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertColor : COLOR;//顶点颜色
                float4 tangent : TANGENT;
             };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 vertColor:COLOR;
            };


            v2f vert(a2v v)
          {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal * _OutlineWidth * 0.1 ,1));   //顶点沿着法线方向外扩
                o.vertColor = v.vertColor.rgb;//访问顶点的rgb
                return o;
            }

            fixed4 frag(v2f i) : SV_TARGET
            {
                return fixed4(_OutLineColor * i.vertColor,0);//返回

            //return _OutLineColor;
            }
          ENDCG
        }
    }
}