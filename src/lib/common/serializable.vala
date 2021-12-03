namespace SystemRTCommon {
	public interface Serializable : GLib.Object {
		public static T @new<T>(GLib.Variant v, string? firstprop = null, ...) {
			var ap = va_list();
			var obj = (Serializable)GLib.Object.@new_valist(typeof (T), firstprop, ap);
			obj.deserialize(v);
			return obj;
		}

		public abstract GLib.Variant serialize_value();
		public abstract void deserialize_value(GLib.Variant v);

		public GLib.Variant serialize() {
			return new GLib.Variant("(sv)", this.get_type().name(), this.serialize_value());
		}

		public void deserialize(GLib.Variant v) {
			string type;
			GLib.Variant inner;
			v.@get("(sv)", out type, out inner);
			GLib.debug("Deserializing type %s", type);
			this.deserialize_value(inner);
		}
	}
}