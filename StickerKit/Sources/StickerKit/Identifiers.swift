/// Identifiers shared by the app and its extensions.
///
/// These must match the entitlements in `project.yml`; a mismatch fails at
/// runtime with an empty container rather than at build time.
public enum Identifiers {
    public static let appGroup = "group.com.blacktree.stickerclip"
    public static let iCloudContainer = "iCloud.app.stickerclip"
}
