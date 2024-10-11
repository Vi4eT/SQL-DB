--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'ProjectOrganizationDB'
GO
USE [master]
GO
ALTER DATABASE [ProjectOrganizationDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [ProjectOrganizationDB]
GO

-- 5 --
------------DATABASE------------
CREATE DATABASE [ProjectOrganizationDB]
GO

USE [ProjectOrganizationDB]
GO

CREATE FUNCTION get_type(@ID int) RETURNS varchar(16) AS
BEGIN
	RETURN (SELECT [Type]
			FROM Employee
			WHERE @ID = ID)
END
GO

CREATE TABLE Employee(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(100) NOT NULL,
	[Birthday] date NOT NULL,
	[Type] varchar(16) NOT NULL 
		CONSTRAINT CK_Employee_Type CHECK ([Type] IN ('�����������', '�������', '������', '��������', '������')),
	[DeptID] int NOT NULL
)
GO

CREATE TABLE Department(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[HeadID] int NULL REFERENCES Employee (ID)
)
GO

ALTER TABLE Employee
ADD FOREIGN KEY (DeptID) REFERENCES Department (ID)
GO

CREATE TABLE [Contract](
	[ID] int PRIMARY KEY,
	[Name] varchar(50) NOT NULL,
	[HeadID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_Contract_HeadID_Type CHECK (dbo.get_type(HeadID) IN ('�����������', '�������')),
	[StartDate] date NOT NULL,
	[EndDate] date NOT NULL,
	CONSTRAINT CK_Contract_Dates CHECK (StartDate <= EndDate)
)
GO

CREATE TABLE Project(
	[ID] int PRIMARY KEY,
	[Name] varchar(50) NOT NULL,
	[HeadID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_Project_HeadID_Type CHECK (dbo.get_type(HeadID) IN ('�����������', '�������')),
	[StartDate] date NOT NULL,
	[EndDate] date NOT NULL,
	[Cost] money NOT NULL,
	CONSTRAINT CK_Project_Dates CHECK (StartDate <= EndDate)
)
GO

CREATE TABLE ProjectEmployee(
	[ProjectID] int NOT NULL REFERENCES Project (ID),
	[EmployeeID] int NOT NULL REFERENCES Employee (ID),
	PRIMARY KEY (ProjectID, EmployeeID)
)
GO

CREATE TABLE ProjectContract(
	[ProjectID] int NOT NULL REFERENCES Project (ID),
	[ContractID] int NOT NULL REFERENCES [Contract] (ID),
	PRIMARY KEY (ProjectID, ContractID)
)
GO

CREATE TABLE Equipment(
	[ID] int PRIMARY KEY,
	[Name] varchar(50) NOT NULL,
	[DefaultDeptID] int NULL REFERENCES Department (ID)
)
GO

CREATE FUNCTION get_start_date(@ID int) RETURNS date AS
BEGIN
	RETURN (SELECT StartDate
			FROM Project
			WHERE @ID = ID)
END
GO

CREATE FUNCTION get_end_date(@ID int) RETURNS date AS
BEGIN
	RETURN (SELECT EndDate
			FROM Project
			WHERE @ID = ID)
END
GO

--TODO: check equipment availability
/*CREATE FUNCTION check_equipment(@ID int, @d1 date, @d2 date) RETURNS int AS
BEGIN
	DECLARE @r int = (SELECT EquipmentID
					  FROM ProjectEquipment
					  WHERE @ID = EquipmentID AND StartDate <= @d1 AND EndDate >= @d2)
	IF @r IS NULL
		RETURN 0
	RETURN @r
END
GO*/

CREATE TABLE ProjectEquipment(
	[ID] int PRIMARY KEY IDENTITY,
	[ProjectID] int NOT NULL REFERENCES Project (ID),
	[EquipmentID] int NOT NULL REFERENCES Equipment (ID),
	[DeptID] int NOT NULL REFERENCES Department (ID),
	[StartDate] date NOT NULL,
	[EndDate] date NOT NULL,
	CONSTRAINT CK_ProjectEquipment_Dates CHECK (StartDate <= EndDate),
	CONSTRAINT CK_ProjectEquipment_StartDate 
		CHECK (StartDate BETWEEN dbo.get_start_date(ProjectID) AND dbo.get_end_date(ProjectID)),
	CONSTRAINT CK_ProjectEquipment_EndDate 
		CHECK (EndDate BETWEEN dbo.get_start_date(ProjectID) AND dbo.get_end_date(ProjectID)),
	--CONSTRAINT CK_ProjectEquipment_EquipmentID CHECK (dbo.check_equipment(EquipmentID, StartDate, EndDate) = 0)
)
GO

CREATE TABLE Outsource(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
)
GO

CREATE TABLE ProjectOutsource(
	[ProjectID] int NOT NULL REFERENCES Project (ID),
	[OutsourceID] int NOT NULL REFERENCES Outsource (ID),
	PRIMARY KEY (ProjectID, OutsourceID)
)
GO


/************************************************/
/* 1 */
--���
SELECT FIO, Birthday, [Type], [Name] Department
FROM Employee e JOIN Department d ON e.DeptID = d.ID
--�����
SELECT FIO, Birthday, [Type]
FROM Employee e JOIN Department d ON e.DeptID = d.ID
WHERE [Name] = '�����2'
--���������
SELECT FIO, Birthday, [Name] Department
FROM Employee e JOIN Department d ON e.DeptID = d.ID
WHERE [Type] = '�������'

/* 2 */
SELECT FIO Head, Birthday, [Type], [Name] Department
FROM Employee e JOIN Department d ON e.ID = d.HeadID

/* 3 */
--������� ��������
DECLARE @a date = GETDATE()
SELECT [Name], StartDate, EndDate
FROM [Contract]
WHERE StartDate <= @a AND EndDate >= @a
GO
--������� � ������� 2020 ����
DECLARE @a date = '20200101'
DECLARE @b date = '20201231'
SELECT [Name], StartDate, EndDate, Cost, FIO Head
FROM Project p JOIN Employee e ON p.HeadID = e.ID
WHERE StartDate BETWEEN @a AND @b OR EndDate BETWEEN @a AND @b
GO

/* 4 */
--������� �� ��������
SELECT [Name], StartDate, EndDate, FIO Head
FROM Project p JOIN Employee e ON p.HeadID = e.ID
WHERE p.ID IN (SELECT ProjectID
			   FROM ProjectContract pc JOIN [Contract] c ON c.ID = pc.ContractID
			   WHERE [Name] = '��������1')
--�������� �� �������
SELECT [Name], StartDate, EndDate, FIO Head
FROM [Contract] c JOIN Employee e ON c.HeadID = e.ID
WHERE c.ID IN (SELECT ContractID
			   FROM ProjectContract pc JOIN Project p ON p.ID = pc.ProjectID
			   WHERE [Name] = '������2')

/* 5 */
--�������, ����������� ��������� � 2020 ����
SELECT [Name] = ISNULL([Name], 'Total'), SUM(Cost) Cost
FROM Project p
WHERE StartDate >= '20200101' AND EndDate <= '20201231'
GROUP BY ROLLUP([Name])
--��������, ����������� ��������� � 2020 ����
SELECT [Name] = ISNULL(c.[Name], 'Total'), COUNT(ProjectID) Projects, SUM(Cost) Cost
FROM Project p JOIN (SELECT *
					 FROM ProjectContract
					 WHERE ContractID IN (SELECT ID
										  FROM [Contract]
										  WHERE StartDate >= '20200101' AND EndDate <= '20201231')) pc ON p.ID = pc.ProjectID
			   JOIN [Contract] c ON c.ID = pc.ContractID
GROUP BY ROLLUP(c.[Name])

/* 6 */
--GETDATE() ��� ������� ����
DECLARE @a date = /*GETDATE()*/'20210613'
SELECT p.[Name] Project, e.[Name] Equipment, d.[Name] Department, pe.StartDate, pe.EndDate
FROM ProjectEquipment pe JOIN Project p ON p.ID = pe.ProjectID
						 JOIN Equipment e ON e.ID = pe.EquipmentID
						 JOIN Department d ON d.ID = pe.DeptID
WHERE pe.StartDate <= @a AND pe.EndDate >= @a
GO

/* 7 */
--�������
SELECT e.[Name] Equipment, d.[Name] Department, pe.StartDate, pe.EndDate
FROM ProjectEquipment pe JOIN Project p ON p.ID = pe.ProjectID
						 JOIN Equipment e ON e.ID = pe.EquipmentID
						 JOIN Department d ON d.ID = pe.DeptID
WHERE p.[Name] = '������1'
--��������
SELECT p.[Name] Project, e.[Name] Equipment, d.[Name] Department, pe.StartDate, pe.EndDate
FROM ProjectEquipment pe JOIN Project p ON p.ID = pe.ProjectID
						 JOIN Equipment e ON e.ID = pe.EquipmentID
						 JOIN Department d ON d.ID = pe.DeptID
WHERE ProjectID IN (SELECT ProjectID
					FROM ProjectContract pc JOIN [Contract] c ON c.ID = pc.ContractID
					WHERE [Name] = '��������1')

/* 8 */
--��������� � �������
DECLARE @a date = '20200101'
DECLARE @b date = '20201231'
SELECT [Name] Project, StartDate, EndDate
FROM Project p JOIN ProjectEmployee pe ON p.ID = pe.ProjectID
			   JOIN Employee e ON e.ID = pe.EmployeeID
WHERE FIO = '������ ���� ��������' AND (StartDate BETWEEN @a AND @b OR EndDate BETWEEN @a AND @b)
GO
--��������� ����������� � ��������
DECLARE @a date = '20200101'
DECLARE @b date = '20201231'
SELECT FIO, [Name] [Contract], StartDate, EndDate
FROM [Contract] c JOIN ProjectContract pc ON c.ID = pc.ContractID
				  JOIN ProjectEmployee pe ON pc.ProjectID = pe.ProjectID
				  JOIN Employee e ON e.ID = pe.EmployeeID
WHERE [Type] = '�����������' AND (StartDate BETWEEN @a AND @b OR EndDate BETWEEN @a AND @b)
GO

/* 9 */
SELECT o.[Name] Organization, p.[Name] Project, StartDate, EndDate, Cost
FROM Project p JOIN ProjectOutsource po ON p.ID = po.ProjectID
			   JOIN Outsource o ON o.ID = po.OutsourceID

/* 10 */
--� �����
SELECT FIO, [Type]
FROM Employee e JOIN ProjectEmployee pe ON e.ID = pe.EmployeeID
				JOIN Project p ON p.ID = pe.ProjectID
WHERE [Name] = '������2'
--���������
SELECT FIO
FROM Employee e JOIN ProjectEmployee pe ON e.ID = pe.EmployeeID
				JOIN Project p ON p.ID = pe.ProjectID
WHERE [Name] = '������2' AND [Type] = '��������'

/* 11 */
SELECT p.[Name] Project
FROM Project p JOIN ProjectEquipment pe ON p.ID = pe.ProjectID
			   JOIN Equipment e ON e.ID = pe.EquipmentID
WHERE e.[Name] = '��������� ������'

/* 12 */
--�����
SELECT c.[Name] [Contract], Cost, [Days], Cost/[Days] [Income per day]
FROM [Contract] c JOIN (SELECT ContractID, SUM(Cost) Cost
						FROM ProjectContract pc JOIN Project p ON p.ID = pc.ProjectID
						GROUP BY ContractID) s1 ON c.ID = s1.ContractID
				  JOIN (SELECT ID, DATEDIFF(day, StartDate, EndDate) [Days]
						FROM [Contract] c) s2 ON c.ID = s2.ID
--����
SELECT c.[Name] [Contract], Cost, Employees, Cost/Employees [Income per employee]
FROM [Contract] c JOIN (SELECT ContractID, SUM(Cost) Cost
						FROM ProjectContract pc JOIN Project p ON p.ID = pc.ProjectID
						GROUP BY ContractID) s1 ON c.ID = s1.ContractID
				  JOIN (SELECT ContractID, COUNT(DISTINCT EmployeeID) Employees
						FROM ProjectContract pc JOIN ProjectEmployee pe ON pe.ProjectID = pc.ProjectID
						GROUP BY ContractID) s2 ON c.ID = s2.ContractID

/* 13 */
--� �����
DECLARE @a date = '20200101'
DECLARE @b date = '20201231'
SELECT p.[Name] Project, FIO, [Type]
FROM Employee e JOIN ProjectEmployee pe ON e.ID = pe.EmployeeID
				JOIN Project p ON p.ID = pe.ProjectID
WHERE StartDate BETWEEN @a AND @b OR EndDate BETWEEN @a AND @b
GO
--���������
DECLARE @a date = '20200101'
DECLARE @b date = '20201231'
SELECT p.[Name] Project, FIO
FROM Employee e JOIN ProjectEmployee pe ON e.ID = pe.EmployeeID
				JOIN Project p ON p.ID = pe.ProjectID
WHERE [Type] = '��������' AND (StartDate BETWEEN @a AND @b OR EndDate BETWEEN @a AND @b)
GO

/* 14 */
--�����
SELECT p.[Name] Project, Cost, [Days], Cost/[Days] [Income per day]
FROM Project p JOIN (SELECT ID, DATEDIFF(day, StartDate, EndDate) [Days]
					 FROM Project p) s ON p.ID = s.ID
--����
SELECT p.[Name] Project, Cost, Employees, Cost/Employees [Income per employee]
FROM Project p JOIN (SELECT ProjectID, COUNT(EmployeeID) Employees
					 FROM ProjectEmployee pe
					 GROUP BY ProjectID) s ON p.ID = s.ProjectID