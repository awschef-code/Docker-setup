package com.dxc.agility.archiva;


import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Properties;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;


public class Backup extends HttpServlet{

    private static final String propertiesFileName = "/WEB-INF/classes/archivaBackup.properties";
    private static final Properties archivaProps = new Properties();
    private static Path extensionsRepoPath;
    public static final String FILENAME_DATE_PATTERN = "yyyy-MM-dd-HH-mm-ss";

    public void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException{
        String zipFilePath = "";
        Path zipPath;
        OutputStream out = response.getOutputStream();

        try {
            archivaProps.load(getServletContext().getResourceAsStream(propertiesFileName));
            extensionsRepoPath = Paths.get(archivaProps.getProperty ("ARCHIVA_EXTENSIONS_REPO_PATH"));
            response.setContentType("application/zip");
            response.addHeader("Content-Disposition", "attachment; filename="+ getZipFileName());
            createZipFile(out);
            response.setStatus(HttpServletResponse.SC_OK);
        }
        catch (Exception zex) {
            response.reset();
            response.setContentType("text/html");
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Failed to export repository. " + zex.getMessage());
        }
        response.flushBuffer();
    }

    private void createZipFile(OutputStream out) throws Exception {
        final ZipOutputStream zos = new ZipOutputStream(out);
        Files.walk(extensionsRepoPath, Integer.MAX_VALUE)
                .filter(currentFile -> (Files.isRegularFile(currentFile) && isValidPath(extensionsRepoPath,currentFile)))
                .forEach(fileToAdd -> addToZipFile(zos, fileToAdd));
        zos.close();
    }

    private void addToZipFile(ZipOutputStream zos, Path fileToAdd) {
        try {
            zos.putNextEntry(new ZipEntry((extensionsRepoPath.relativize(fileToAdd)).toString()));
            Files.copy(fileToAdd, zos);
            zos.closeEntry();
            zos.flush();
        }
        catch (IOException iex) {
            throw new RuntimeException(iex);
        }
    }

    private String getZipFileName() {
        String timeStampForFileName = (new SimpleDateFormat(FILENAME_DATE_PATTERN)).format(new Date());
        return "extensions_repo_backup" + "_" + timeStampForFileName + ".zip";
    }

    private static boolean isValidPath(Path srcPath, Path filePath) {
        String relativePath = srcPath.relativize(filePath).toString();
        return !(relativePath.startsWith(".") ||  relativePath.contains(File.separator+ ".") || filePath.getFileName().toString().startsWith("."));
    }

    public static void main(String[] args) {
        System.out.println("getenv: " + System.getenv("ARCHIVA_EXTENSIONS_REPO_PATH"));
        System.out.println("getProperty: " + System.getProperty("ARCHIVA_EXTENSIONS_REPO_PATH"));
    }
}
