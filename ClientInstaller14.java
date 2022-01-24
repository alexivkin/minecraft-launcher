// Adding back the missing functionality for the Forge installer to launch the client install from the CLI
import java.io.OutputStream;
import java.io.File;
import java.io.IOException;

import net.minecraftforge.installer.json.Install;
import net.minecraftforge.installer.json.Util;
import net.minecraftforge.installer.SimpleInstaller;
import net.minecraftforge.installer.actions.Actions;
import net.minecraftforge.installer.actions.ProgressCallback;

public class ClientInstaller14 {
  public static void main(String[] args) throws IOException {
    SimpleInstaller.headless = true;
    System.setProperty("java.net.preferIPv4Stack", "true");
    ProgressCallback monitor = ProgressCallback.withOutputs(new OutputStream[] { System.out });
    Actions action = Actions.CLIENT;
    try {
        Install install = Util.loadInstallProfile();
        if (install.getSpec() != 0) {
          System.out.println("Bad launcher profile: " + install.getSpec());
          System.exit(1);
        }
        if (!action.getAction(install, monitor).run(new File("."), a -> true)) {
          System.out.println("Error");
          System.exit(1);
        }
        System.out.println(action.getSuccess(install.getPath().getName()));
    } catch (Throwable e) {
        e.printStackTrace();
        System.exit(1);
    }
    System.exit(0);
  }
}
