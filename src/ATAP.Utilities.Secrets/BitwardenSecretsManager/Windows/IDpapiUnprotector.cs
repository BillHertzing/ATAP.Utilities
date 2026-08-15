namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public interface IDpapiUnprotector
{
  byte[] UnprotectForCurrentUser(byte[] ciphertext);
}