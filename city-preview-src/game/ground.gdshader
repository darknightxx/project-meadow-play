shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D layout_tex : filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 vec3 mask=texture(layout_tex,p/160.0).rgb;
 vec3 base=texture(grass_tex,p/6.0).rgb;
 base=mix(base,texture(dirt_tex,p/4.5).rgb,mask.g);
 base=mix(base,texture(stone_tex,p/3.4).rgb,mask.r);
 base=mix(base,texture(dirt_tex,p/4.0).rgb*vec3(1.08,1.03,.9),mask.b);
 float terrace=step(60.0,p.x)*step(p.x,100.0)*step(p.y,37.5);
 ALBEDO=mix(base,texture(tile_tex,p/3.0).rgb,terrace);
 ROUGHNESS=.92;
}
