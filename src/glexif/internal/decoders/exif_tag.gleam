import gleam/dynamic.{
  type DecodeError, type Decoder, type Dynamic, field, float, int, list,
  optional_field, string,
}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import glexif/exif_tag
import glexif/exif_tags/components_configuration.{type ComponentsConfiguration}
import glexif/exif_tags/exposure_program
import glexif/exif_tags/flash
import glexif/exif_tags/metering_mode
import glexif/exif_tags/orientation
import glexif/exif_tags/resolution_unit
import glexif/exif_tags/y_cb_cr_positioning
import glexif/internal/utils
import glexif/units/fraction.{type Fraction, Fraction}

pub fn exif_tag_decoder() {
  decode_exif_record(
    exif_tag.ExifTagRecordSimple,
    optional_field(named: "ImageDescription", of: string),
    optional_field(named: "Make", of: string),
    optional_field(named: "Model", of: string),
    optional_field(named: "Orientation", of: decode_orientation),
    optional_field(named: "XResolution", of: int),
    optional_field(named: "YResolution", of: int),
    optional_field(named: "ResolutionUnit", of: decode_resolution_unit),
    optional_field(named: "Software", of: string),
    optional_field(named: "ModifyDate", of: string),
    optional_field(named: "HostComputer", of: string),
    optional_field(named: "YCbCrPositioning", of: decode_y_cb_cr_positioning),
    optional_field(named: "ExposureTime", of: decode_fraction),
    optional_field(named: "FNumber", of: float),
    optional_field(named: "ExposureProgram", of: decode_exposure_program),
    optional_field(named: "ISO", of: int),
    optional_field(named: "ExifVersion", of: string),
    optional_field(named: "DateTimeOriginal", of: string),
    optional_field(named: "CreateDate", of: string),
    optional_field(named: "OffsetTime", of: string),
    optional_field(named: "OffsetTimeOriginal", of: string),
    optional_field(named: "OffsetTimeDigitized", of: string),
    optional_field(
      named: "ComponentsConfiguration",
      of: decode_components_configuration,
    ),
    // optional_field(named: "ShutterSpeedValue", of: decode_fraction),
    optional_field(named: "ApertureValue", of: float),
    optional_field(named: "BrightnessValue", of: float),
    optional_field(named: "ExposureCompensation", of: decode_int_to_float),
    optional_field(named: "MeteringMode", of: decode_metering_mode),
    optional_field(named: "Flash", of: decode_flash),
    optional_field(named: "ocalLength", of: decode_focal_length),
  )
}

pub fn decode_focal_length(
  from_data: Dynamic,
) -> Result(Float, List(DecodeError)) {
  string(from_data)
  |> result.map(fn(v) { string.split(v, " ") })
  |> result.unwrap([])
  |> list.first
  |> result.map(float.parse)
  |> result.flatten
  |> result.map_error(fn(_) { [dynamic.DecodeError("focal lengh", "", [])] })
}

pub fn decode_flash(
  from_data: Dynamic,
) -> Result(flash.Flash, List(DecodeError)) {
  case string(from_data) {
    Ok("Off, Did not fire") -> Ok(flash.OffDidNotFire)
    Ok(v) -> Error([dynamic.DecodeError("flash", v, [])])
    _ -> Error([])
  }
}

pub fn decode_metering_mode(
  from_data: Dynamic,
) -> Result(metering_mode.MeteringMode, List(DecodeError)) {
  case string(from_data) {
    Ok("Multi-segment") -> Ok(metering_mode.MultiSegement)
    Ok(val) -> Error([dynamic.DecodeError("metering mode", val, [])])
    Error(v) -> Error(v)
  }
}

pub fn decode_int_to_float(
  from_data: Dynamic,
) -> Result(Float, List(DecodeError)) {
  int(from_data)
  |> result.map(fn(r) { int.to_float(r) })
}

pub fn decode_components_configuration(
  from_data: Dynamic,
) -> Result(List(ComponentsConfiguration), List(DecodeError)) {
  string(from_data)
  |> result.map_error(fn(_) { Nil })
  |> result.map(string.split(_, ","))
  |> result.unwrap([])
  |> list.map(string.trim)
  |> list.map(fn(v) {
    case v {
      "Y" -> components_configuration.Y
      "Cb" -> components_configuration.Cb
      "Cr" -> components_configuration.Cr
      "R" -> components_configuration.R
      "G" -> components_configuration.G
      "B" -> components_configuration.B
      "-" -> components_configuration.NA
      _ -> components_configuration.InvalidComponentsConfiguration
    }
  })
  |> Ok
}

pub fn decode_fraction(
  from_data: Dynamic,
) -> Result(Fraction, List(DecodeError)) {
  string(from_data)
  |> result.map_error(fn(_) { Nil })
  |> result.try(string.split_once(_, "/"))
  |> result.try(fn(vals) {
    case int.parse(vals.0), int.parse(vals.1) {
      Ok(numerator), Ok(denominator) ->
        Ok(utils.simplify_fraction(Fraction(numerator, denominator)))
      _, _ -> Error(Nil)
    }
  })
  |> result.map_error(fn(_) {
    [dynamic.DecodeError("fraction", "something else", [])]
  })
}

pub fn decode_exposure_program(
  from_data: Dynamic,
) -> Result(exposure_program.ExposureProgram, List(DecodeError)) {
  case string(from_data) {
    Ok("Program AE") -> Ok(exposure_program.ProgramAE)
    Ok(s) -> Error([dynamic.DecodeError("exposure program", s, [])])
    Error(v) -> Error(v)
  }
}

pub fn decode_y_cb_cr_positioning(
  from_data: Dynamic,
) -> Result(y_cb_cr_positioning.YCbCrPositioning, List(DecodeError)) {
  case string(from_data) {
    Ok("Co-sited") -> Ok(y_cb_cr_positioning.CoSited)
    Ok("Centered") -> Ok(y_cb_cr_positioning.Centered)
    Ok(v) -> Error([dynamic.DecodeError("YCbCrPositioning", v, [])])
    _ -> Error([])
  }
}

pub fn decode_resolution_unit(
  from_data: Dynamic,
) -> Result(resolution_unit.ResolutionUnit, List(DecodeError)) {
  case string(from_data) {
    Ok("inches") -> Ok(resolution_unit.Inches)
    Ok("centimeters") -> Ok(resolution_unit.Centimeters)
    _ -> Error([])
  }
}

pub fn decode_orientation(
  from_data: Dynamic,
) -> Result(orientation.Orientation, List(DecodeError)) {
  case string(from_data) {
    Ok("Horizontal (normal)") -> Ok(orientation.Horizontal)
    Ok("Rotate 90 CW") -> Ok(orientation.Rotate90CW)
    Ok("Rotate 180") -> Ok(orientation.Rotate180)
    Ok("Rotate 270 CW") -> Ok(orientation.Rotate270CW)
    Ok("Mirror Vertical") -> Ok(orientation.MirrorVertical)
    Ok("Mirror Horizontal") -> Ok(orientation.MirrorHorizontal)
    Ok(v) -> Error([dynamic.DecodeError("orientation", v, [])])
    _ -> Error([])
  }
}

fn all_errors(result: Result(a, List(DecodeError))) -> List(DecodeError) {
  case result {
    Ok(_) -> []
    Error(errors) -> errors
  }
}

pub fn decode_exif_record(
  constructor: fn(
    t1,
    t2,
    t3,
    t4,
    t5,
    t6,
    t7,
    t8,
    t9,
    t10,
    t11,
    t12,
    t13,
    t14,
    t15,
    t16,
    t17,
    t18,
    t19,
    t20,
    t21,
    t22,
    t23,
    t24,
    t25,
    t26,
    t27,
    t28,
    // t29,
    // t30,
    // t31,
    // t32,
    // t33,
    // t34,
    // t35,
    // t36,
    // t37,
    // t38,
    // t39,
    // t40,
    // t41,
    // t42,
    // t43,
    // t44,
    // t45,
    // t46,
    // t47,
    // t48,
    // t49,
    // t50,
    // t51,
    // t52,
    // t53,
    // t54,
    // t55,
    // t56,
    // t57,
    // t58,
    // t59,
    // t60,
    // t61,
    // t62,
    // t63,
  ) ->
    t,
  t1: Decoder(t1),
  t2: Decoder(t2),
  t3: Decoder(t3),
  t4: Decoder(t4),
  t5: Decoder(t5),
  t6: Decoder(t6),
  t7: Decoder(t7),
  t8: Decoder(t8),
  t9: Decoder(t9),
  t10: Decoder(t10),
  t11: Decoder(t11),
  t12: Decoder(t12),
  t13: Decoder(t13),
  t14: Decoder(t14),
  t15: Decoder(t15),
  t16: Decoder(t16),
  t17: Decoder(t17),
  t18: Decoder(t18),
  t19: Decoder(t19),
  t20: Decoder(t20),
  t21: Decoder(t21),
  t22: Decoder(t22),
  t23: Decoder(t23),
  t24: Decoder(t24),
  t25: Decoder(t25),
  t26: Decoder(t26),
  t27: Decoder(t27),
  t28: Decoder(t28),
  // t29: Decoder(t29),
  // t30: Decoder(t30),
  // t31: Decoder(t31),
  // t32: Decoder(t32),
  // t33: Decoder(t33),
  // t34: Decoder(t34),
  // t35: Decoder(t35),
  // t36: Decoder(t36),
  // t37: Decoder(t37),
  // t38: Decoder(t38),
  // t39: Decoder(t39),
  // t40: Decoder(t40),
  // t41: Decoder(t41),
  // t42: Decoder(t42),
  // t43: Decoder(t43),
  // t44: Decoder(t44),
  // t45: Decoder(t45),
  // t46: Decoder(t46),
  // t47: Decoder(t47),
  // t48: Decoder(t48),
  // t49: Decoder(t49),
  // t50: Decoder(t50),
  // t51: Decoder(t51),
  // t52: Decoder(t52),
  // t53: Decoder(t53),
  // t54: Decoder(t54),
  // t55: Decoder(t55),
  // t56: Decoder(t56),
  // t57: Decoder(t57),
  // t58: Decoder(t58),
  // t59: Decoder(t59),
  // t60: Decoder(t60),
  // t61: Decoder(t61),
  // t62: Decoder(t62),
  // t63: Decoder(t63),
) -> Decoder(t) {
  fn(x: Dynamic) {
    case
      t1(x),
      t2(x),
      t3(x),
      t4(x),
      t5(x),
      t6(x),
      t7(x),
      t8(x),
      t9(x),
      t10(x),
      t11(x),
      t12(x),
      t13(x),
      t14(x),
      t15(x),
      t16(x),
      t17(x),
      t18(x),
      t19(x),
      t20(x),
      t21(x),
      t22(x),
      t23(x),
      t24(x),
      t25(x),
      t26(x),
      t27(x),
      t28(x)
    {
      // t29(x),
      // t30(x),
      // t31(x),
      // t32(x),
      // t33(x),
      // t34(x),
      // t35(x),
      // t36(x),
      // t37(x),
      // t38(x),
      // t39(x),
      // t40(x),
      // t41(x),
      // t42(x),
      // t43(x),
      // t44(x),
      // t45(x),
      // t46(x),
      // t47(x),
      // t48(x),
      // t49(x),
      // t50(x),
      // t51(x),
      // t52(x),
      // t53(x),
      // t54(x),
      // t55(x),
      // t56(x),
      // t57(x),
      // t58(x),
      // t59(x),
      // t60(x),
      // t61(x),
      // t62(x),
      // t63(x)
      Ok(a),
        Ok(b),
        Ok(c),
        Ok(d),
        Ok(e),
        Ok(f),
        Ok(g),
        Ok(h),
        Ok(i),
        Ok(j),
        Ok(k),
        Ok(l),
        Ok(m),
        Ok(n),
        Ok(o),
        Ok(p),
        Ok(q),
        Ok(r),
        Ok(s),
        Ok(t),
        Ok(u),
        Ok(v),
        Ok(w),
        Ok(x1),
        Ok(y),
        Ok(z),
        Ok(aa),
        Ok(bb)
      ->
        // Ok(cc),
        // Ok(dd),
        // Ok(ee),
        // Ok(ff),
        // Ok(gg),
        // Ok(hh),
        // Ok(ii),
        // Ok(jj),
        // Ok(kk),
        // Ok(ll),
        // Ok(mm),
        // Ok(nn),
        // Ok(oo),
        // Ok(pp),
        // Ok(qq),
        // Ok(rr),
        // Ok(ss),
        // Ok(tt),
        // Ok(uu),
        // Ok(vv),
        // Ok(ww),
        // Ok(xx),
        // Ok(yy),
        // Ok(zz),
        // Ok(aaa),
        // Ok(bbb),
        // Ok(ccc),
        // Ok(ddd),
        // Ok(eee),
        // Ok(fff),
        // Ok(ggg),
        // Ok(hhh),
        // Ok(iii),
        // Ok(jjj),
        // Ok(kkk)
        Ok(constructor(
          a,
          b,
          c,
          d,
          e,
          f,
          g,
          h,
          i,
          j,
          k,
          l,
          m,
          n,
          o,
          p,
          q,
          r,
          s,
          t,
          u,
          v,
          w,
          x1,
          y,
          z,
          aa,
          bb,
          // cc,
        // dd,
        // ee,
        // ff,
        // gg,
        // hh,
        // ii,
        // jj,
        // kk,
        // ll,
        // mm,
        // nn,
        // oo,
        // pp,
        // qq,
        // rr,
        // ss,
        // tt,
        // uu,
        // vv,
        // ww,
        // xx,
        // yy,
        // zz,
        // aaa,
        // bbb,
        // ccc,
        // ddd,
        // eee,
        // fff,
        // ggg,
        // hhh,
        // iii,
        // jjj,
        // kkk,
        ))
      a,
        b,
        c,
        d,
        e,
        f,
        g,
        h,
        i,
        j,
        k,
        l,
        m,
        n,
        o,
        p,
        q,
        r,
        s,
        t,
        u,
        v,
        w,
        x1,
        y,
        z,
        aa,
        bb
      ->
        // cc,
        // dd,
        // ee,
        // ff,
        // gg,
        // hh,
        // ii,
        // jj,
        // kk,
        // ll,
        // mm,
        // nn,
        // oo,
        // pp,
        // qq,
        // rr,
        // ss,
        // tt,
        // uu,
        // vv,
        // ww,
        // xx,
        // yy,
        // zz,
        // aaa,
        // bbb,
        // ccc,
        // ddd,
        // eee,
        // fff,
        // ggg,
        // hhh,
        // iii,
        // jjj,
        // kkk
        Error(
          list.concat([
            all_errors(a),
            all_errors(b),
            all_errors(c),
            all_errors(d),
            all_errors(e),
            all_errors(f),
            all_errors(g),
            all_errors(h),
            all_errors(i),
            all_errors(j),
            all_errors(k),
            all_errors(l),
            all_errors(m),
            all_errors(n),
            all_errors(o),
            all_errors(p),
            all_errors(q),
            all_errors(r),
            all_errors(s),
            all_errors(t),
            all_errors(u),
            all_errors(v),
            all_errors(w),
            all_errors(x1),
            all_errors(y),
            all_errors(z),
            all_errors(aa),
            all_errors(bb),
            // all_errors(cc),
          // all_errors(dd),
          // all_errors(ee),
          // all_errors(ff),
          // all_errors(gg),
          // all_errors(hh),
          // all_errors(ii),
          // all_errors(jj),
          // all_errors(kk),
          // all_errors(ll),
          // all_errors(mm),
          // all_errors(nn),
          // all_errors(oo),
          // all_errors(pp),
          // all_errors(qq),
          // all_errors(rr),
          // all_errors(ss),
          // all_errors(tt),
          // all_errors(uu),
          // all_errors(vv),
          // all_errors(ww),
          // all_errors(xx),
          // all_errors(yy),
          // all_errors(zz),
          // all_errors(aaa),
          // all_errors(bbb),
          // all_errors(ccc),
          // all_errors(ddd),
          // all_errors(eee),
          // all_errors(fff),
          // all_errors(ggg),
          // all_errors(hhh),
          // all_errors(iii),
          // all_errors(jjj),
          // all_errors(kkk),
          ]),
        )
    }
  }
}
