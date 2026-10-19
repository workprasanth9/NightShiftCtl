/// Project wide constants shared by the command line tool, the menu bar app,
/// and the build scripts (which read these lines with sed).
public enum NightShiftCtlVersion {
    public static let current = "1.1.1"
}

public enum NightShiftCtlLinks {
    /// The one place the project link is defined. The app's welcome window and
    /// menu use it, and Scripts/build-app-pkg.sh copies it into the installer's
    /// thank you page. Add any future support link next to it, in this file.
    public static let repositoryURL = "https://github.com/workprasanth9/NightShiftCtl"
}
