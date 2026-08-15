namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public interface IBwsDpapiProtector
{
  byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy);
}