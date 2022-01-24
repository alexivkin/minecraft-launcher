// Adding back the missing functionality for the Forge installer to launch the client install from the CLI
import java.io.OutputStream;
import java.io.File;
import java.io.IOException;

import net.minecraftforge.installer.json.InstallV1;
import net.minecraftforge.installer.json.Util;
import net.minecraftforge.installer.SimpleInstaller;
import net.minecraftforge.installer.actions.Actions;
import net.minecraftforge.installer.actions.ProgressCallback;

public class ClientInstaller36 {
  public static void main(String[] args) throws IOException {
    SimpleInstaller.headless = true;
    System.setProperty("java.net.preferIPv4Stack", "true");
    ProgressCallback monitor = ProgressCallback.withOutputs(new OutputStream[] { System.out });
    Actions action = Actions.CLIENT;
    try {
        InstallV1 install = Util.loadInstallProfile();
        File installer = new File(SimpleInstaller.class.getProtectionDomain().getCodeSource().getLocation().toURI());
        if (!action.getAction(install, monitor).run(new File("."), a -> true, installer)) {
          System.out.println("Error");
          System.exit(1);
        }
        System.out.println(action.getSuccess());
    } catch (Throwable e) {
        e.printStackTrace();
        System.exit(1);
    }
    System.exit(0);
  }
}
