USE [master]
GO

-- Create the database, with the standard SQL Server defaults as of 12/2020
CREATE DATABASE [FileSystemAsGraphDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'FileSystemAsGraphDB', FILENAME = N'C:\LocalDBs\Data\FileSystemAsGraphDB.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'FileSystemAsGraphDB_log', FILENAME = N'C:\LocalDBs\Logs\FileSystemAsGraphDB_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [FileSystemAsGraphDB].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ANSI_NULLS OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ANSI_PADDING OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ARITHABORT OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET AUTO_CLOSE OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET AUTO_SHRINK OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET  DISABLE_BROKER 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET TRUSTWORTHY OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET RECOVERY FULL 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET  MULTI_USER 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE [FileSystemAsGraphDB] SET DB_CHAINING OFF 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET DELAYED_DURABILITY = DISABLED 
GO

ALTER DATABASE [FileSystemAsGraphDB] SET QUERY_STORE = OFF
GO

ALTER DATABASE [FileSystemAsGraphDB] SET  READ_WRITE 
GO

