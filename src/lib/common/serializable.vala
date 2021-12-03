namespace SystemRTCommon {
	public interface Serializable : GLib.Object {
		public static T @new<T>(GLib.Variant v, string? firstprop = null, ...) {
			var ap = va_list();
			var obj = (Serializable)GLib.Object.@new_valist(typeof (T), firstprop, ap);
			obj.deserialize(v);
			return obj;
		}

		public abstract GLib.Variant serialize();
		public abstract void deserialize(GLib.Variant v);
	}
}