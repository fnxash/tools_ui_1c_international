// Query console 9000 v 1.1.10
// (C) Alexander Kuznetsov 2019-2020
// hal@hal9000.cc
//Minimum platform version 8.3.12, minimum compatibility mode 8.3.8
// Translated by Neti Company

Procedure Initializing(Form = Undefined, cSessionID = Undefined) Export

	DataProcessorVersion = "1.1.10";
	BuildVersion = 1;

	Hashing = New DataHashing(HashFunction.CRC32);
	Hashing.Append(InfoBaseConnectionString());
	IBString = Format(Hashing.HashSum, "NG=0");

	If cSessionID = Undefined Then
		Hashing.Append(UserName());
		SessionID = Hashing.HashSum;
	Else
		SessionID = cSessionID;
	EndIf;

	LockedQueriesExtension = "9000_" + Format(SessionID, "NG=0");

	DataProcessorMetadata = Metadata();

	Try
		UsingDataProcessorFileName = Eval("UsingFileName");

		ExternalDataProcessorMode = True;

		MetadataPath = "ExternalDataProcessor." + DataProcessorMetadata.Name;

		If Mid(UsingDataProcessorFileName, 2, 2) = ":\" Or Left(UsingDataProcessorFileName, 1)
			= "/" Then
			DataProcessorFileName = UsingDataProcessorFileName;
		EndIf;

	Except
		DataProcessorName = DataProcessorMetadata.Name;
		MetadataPath = StrTemplate("DataProcessor.%1", DataProcessorName);
	EndTry;
	
	//Startup info.
	//If ExternalDataProcessorMode = False - run from configuration or extension.
	//
	//If ExternalDataProcessorMode = True, then:
	//	If DataProcessorFileName is not blank - this is external data processor from file, if blank - from binary data.

	If Form <> Undefined Then

		PicturesTemplate = GetTemplate("Pictures");
		stPictures = New Structure;
		For Each Area In PicturesTemplate.Areas Do
			If TypeOf(Area) = Type("SpreadsheetDocumentDrawing") Then
				stPictures.Insert(Area.Name, Area.Picture);
			EndIf;
		EndDo;

		Pictures = PutToTempStorage(stPictures, Form.UUID);

		IBStorageStructure = PutToTempStorage(Undefined, Form.UUID);

	EndIf;

EndProcedure

Function StringToValue(StringValue) Export
	Reader = New XMLReader;
	Reader.SetString(StringValue);
	Return XDTOSerializer.ReadXML(Reader);
EndFunction

Function ValueToString(Value) Export
	Writer = New XMLWriter;
	Writer.SetString();
	XDTOSerializer.WriteXML(Writer, Value);
	Return Writer.Close();
EndFunction

Function GetPictureByType(ValueType, PicturesStructure = Undefined) Export

	PictureName = Undefined;
	If TypeOf(ValueType) = Type("TypeDescription") Then

		arTypes = ValueType.Types();

		PictureName = Undefined;
		For Each Type In arTypes Do
			TypePictureName = GetTypePictureName(Type);
			If PictureName = Undefined Then
				PictureName = TypePictureName;
			ElsIf PictureName <> TypePictureName Then
				PictureName = "Type_Undefined";
				Break;
			EndIf;
		EndDo;

	ElsIf TypeOf(ValueType) = Type("String") Then
		PictureName = GetTypePictureName(ValueType);
	EndIf;

	If PicturesStructure = Undefined Then
		PicturesStructure = GetFromTempStorage(Pictures);
	EndIf;

	If PictureName = Undefined Then
		PictureName = "Type_Undefined";
	EndIf;

	Picture = Undefined;
	PicturesStructure.Property(PictureName, Picture);
	Return Picture;

EndFunction

Function NoEmptyType(TypeDescription) Export

	If TypeOf(TypeDescription) <> Type("TypeDescription") Then
		Return TypeDescription;
	EndIf;

	arEmptyTypes = New Array;
	arEmptyTypes.Add(Type("Null"));
	arEmptyTypes.Add(Type("Undefined"));

	Return New TypeDescription(TypeDescription, , arEmptyTypes);

EndFunction
			
//Value - Type or String - ValueType field content.
Function GetTypePictureName(Value) Export

	If Value = "Value table" Then
		Return "Type_ValueTable";
	ElsIf Value = Type("Array") Then
		Return "Type_Array";
	ElsIf Value = Type("ValueList") Then
		Return "Type_ValueList";
	ElsIf Value = Type("String") Then
		Return "Type_String";
	ElsIf Value = Type("Number") Then
		Return "Type_Number";
	ElsIf Value = Type("Boolean") Then
		Return "Type_Boolean";
	ElsIf Value = Type("Date") Then
		Return "Type_Date";
	ElsIf Value = Type("Boundary") Then
		Return "Type_Boundary";
	ElsIf Value = Type("PointInTime") Then
		Return "Type_PointInTime";
	ElsIf Value = Type("Type") Then
		Return "Type_Type";
	ElsIf Value = Type("UUID") Then
		Return "Type_UUID";
	ElsIf Value = Type("Undefined") Then
		Return "Type_Undefined";
	ElsIf Catalogs.AllRefsType().ContainsType(Value) Then
		Return "Type_CatalogRef";
		;
	ElsIf Documents.AllRefsType().ContainsType(Value) Then
		Return "Type_DocumentRef";
	ElsIf Enums.AllRefsType().ContainsType(Value) Then
		Return "Type_EnumRef";
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Value) Then
		Return "Type_ChartOfCharacteristicTypesRef";
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Value) Then
		Return "Type_ChartOfAccountsRef";
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Value) Then
		Return "Type_ChartOfCalculationTypesRef";
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Value) Then
		Return "Type_BusinessProcessRef";
	ElsIf Tasks.AllRefsType().ContainsType(Value) Then
		Return "Type_TaskRef";
	ElsIf ExchangePlans.AllRefsType().ContainsType(Value) Then
		Return "Type_ExchangePlanRef";
	ElsIf Value = Type("Null") Then
		Return "Type_Null";
	ElsIf Value = Type("AccountingRecordType") Then
		Return "Type_AccountingRecordType";
	ElsIf Value = Type("AccumulationRecordType") Then
		Return "Type_AccumulationRecordType";
	ElsIf Value = Type("AccountType") Then
		Return "Type_AccountType";
	Else
		Return "Type_Undefined";
	EndIf;

EndFunction

Function GetTypeName(Value) Export

	ar = New Array;
	ar.Add(Value);
	ValueTypesDescription = New TypeDescription(ar);
	TypeValue = ValueTypesDescription.AdjustValue(Undefined);

	If Value = Type("Undefined") Then
		Return "Undefined";
	ElsIf Catalogs.AllRefsType().ContainsType(Value) Then
		Return "CatalogRef." + TypeValue.Metadata().Name;
	ElsIf Documents.AllRefsType().ContainsType(Value) Then
		Return "DocumentRef." + TypeValue.Metadata().Name;
	ElsIf Enums.AllRefsType().ContainsType(Value) Then
		Return "EnumRef." + TypeValue.Metadata().Name;
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Value) Then
		Return "ChartOfCharacteristicTypesRef." + TypeValue.Metadata().Name;
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Value) Then
		Return "ChartOfAccountsRef." + TypeValue.Metadata().Name;
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Value) Then
		Return "ChartOfCalculationTypesRef." + TypeValue.Metadata().Name;
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Value) Then
		Return "BusinessProcessRef." + TypeValue.Metadata().Name;
	ElsIf Tasks.AllRefsType().ContainsType(Value) Then
		Return "TaskRef." + TypeValue.Metadata().Name;
	ElsIf ExchangePlans.AllRefsType().ContainsType(Value) Then
		Return "ExchangePlanRef." + TypeValue.Metadata().Name;
	ElsIf Value = Type("Null") Then
		Return "Null";
	ElsIf Value = Type("AccountingRecordType") Then
		Return "AccountingRecordType";
	ElsIf Value = Type("AccumulationRecordType") Then
		Return "AccumulationRecordType";
	ElsIf Value = Type("AccountType") Then
		Return "AccountType";
	Else
		Return String(Value);
	EndIf;

EndFunction

Function GetTypesUndisplayableAtClient()
	arTypes = New Array;
	arTypes.Add(Type("Type"));
	arTypes.Add(Type("PointInTime"));
	arTypes.Add(Type("Boundary"));
	arTypes.Add(Type("ValueStorage"));
	arTypes.Add(Type("QueryResult"));
	Return arTypes;
EndFunction

Function ValueListFromArray(arArray)
	vlList = New ValueList;
	vlList.LoadValues(arArray);
	Return vlList;
EndFunction

Procedure ChangeValueTableColumnType(vtData, ColumnName, NewColumnType) Export
	TempColumnName = ColumnName + "_Tmp31415926";
	arColumnData = vtData.UnloadColumn(ColumnName);
	vtData.Columns.Add(TempColumnName, NewColumnType);
	vtData.LoadColumn(arColumnData, TempColumnName);
	vtData.Columns.Delete(ColumnName);
	vtData.Columns[TempColumnName].Name = ColumnName;
EndProcedure

//Delets NULL from column types, if no NULL values contains in data
Procedure ValueTable_DeleteNullType(vtTable) Export

	arRemovedTypes = New Array;
	arRemovedTypes.Add(Type("Null"));

	stProcessedColumns = New Structure;
	vtNewTable = New ValueTable;
	For Each Column In vtTable.Columns Do

		If Column.ТипЗначения.СодержитТип(Тип("Null")) Then
			arRowsWithNull = vtTable.FindRows(New Structure(Column.Name, Null));
			If arRowsWithNull.Count() = 0 Then
				stProcessedColumns.Insert(Column.Name);
				vtNewTable.Columns.Add(Column.Name, New TypeDescription(Column.ValueType, ,
					arRemovedTypes));
				Continue;
			EndIf;
		EndIf;

		vtNewTable.Columns.Add(Column.Name, Column.ValueType);

	EndDo;

	If stProcessedColumns.Количество() = 0 Then
		Return;
	EndIf;

	For Each Row In vtTable Do
		FillPropertyValues(vtNewTable.Add(), Row);
	EndDo;

	vtTable = vtNewTable;

EndProcedure

Procedure ProcessMacrocolumns(QueryResultString, selSelection, stMacrocolumns) Export
	For Each kv In stMacrocolumns Do
		If kv.Value.Type = "UUID" Then
			Value = QueryResultString[kv.Value.SourceColumn];
			If ValueIsFilled(Value) Then
				QueryResultString[kv.Key] = Value.UUID();
			EndIf;
		EndIf;
	EndDo;
EndProcedure

#Region RegexpMatchChecking

Function RegTemplate_GetTemplateObject(Template) Export

	Reader = New XMLReader;
	Reader.SetString(
                "<Model xmlns=""http://v8.1c.ru/8.1/xdto"" xmlns:xs=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xsi:type=""Model"">
				|<package targetNamespace=""sample-my-package"">
				|<valueType name=""testtypes"" base=""xs:string"">
				|<pattern>" + Template + "</pattern>
									   |</valueType>
									   |<objectType name=""TestObj"">
									   |<property xmlns:d4p1=""sample-my-package"" name=""TestItem"" type=""d4p1:testtypes""/>
									   |</objectType>
									   |</package>
									   |</Model>");

	Model = XDTOFactory.ReadXML(Reader);
	MyXDTOFactory = New XDTOFactory(Model);
	Package = MyXDTOFactory.Packages.Get("sample-my-package");
	XDTOTemplate = MyXDTOFactory.Create(Package.Get("TestObj"));

	Return XDTOTemplate;

EndFunction

Function RegTemplate_Match(Row, Template) Экспорт

	If TypeOf(Template) = Type("String") Then
		TemplateObject = RegTemplate_GetTemplateObject(Template);
	Else
		TemplateObject = Template;
	EndIf;

	Try
		TemplateObject.TestItem = Row;
		Return True;
	Except
		Return False;
	EndTry;

EndFunction

#EndRegion

#Region TechnologicalLog


Function TechnologicalLog_GetAppConfigurationFolder()
	
	//SystemInfo = New SystemInfo();
	//If Not ((SystemInfo.PlatformType = PlatformType.Windows_x86) Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64)) Then
	//	Return Undefined;
	//EndIf;

	CommonConfigurationFilesFolder = BinDir() + "conf";
	PointerFile = New File(CommonConfigurationFilesFolder + GetServerPathSeparator() + "conf.cfg");
	If PointerFile.Exists() Then
		ConfigurationFile = New TextReader(PointerFile.FullName);
		Line = ConfigurationFile.ReadLine();
		While Line <> Undefined Do
			Position = StrFind(Line, "ConfLocation=");
			If Position > 0 Then
				AppConfigurationFolder = TrimAll(Mid(Line, Position + 13));
				Break;
			EndIf;
			Line = ConfigurationFile.ReadLine();
		EndDo;
	EndIf;

	Return AppConfigurationFolder;

EndFunction

Function TechnologicalLog_ConsoleLabel()
	Return StrTemplate("QueryConsole9000_%1", Format(SessionID, "ЧГ=0"));
EndFunction

Function TechnologicalLog_DOM_TLConfig(Document) Export
	Return Document.FirstChild.NamespaceURI = "http://v8.1c.ru/v8/tech-log"
		And Document.FirstChild.NodeName = "config";
EndFunction

Function TechnologicalLog_RemoveConsloleLogFromDOM(Document) Export

	Label = TechnologicalLog_ConsoleLabel();

	arDeletingNodes = New Array;

	DeletingMode = False;
	For Each Node In Document.FirstChild.ChildNodes Do

		If Node.NodeName = "#comment" And TrimAll(Node.NodeValue) = Label Тогда

			If DeletingMode Then
				arDeletingNodes.Добавить(Node);
				DeletingMode = False;
			Else
				DeletingMode = True;
			EndIf;

		EndIf;

		If DeletingMode Then
			arDeletingNodes.Add(Node);
		EndIf;

	EndDo;

	For Each Node In arDeletingNodes Do
		Document.FirstChild.RemoveChild(Node);
	EndDo;

	Return arDeletingNodes.Count() > 0;

EndFunction

Procedure TechnologicalLog_WriteDOM(Document, FileName) Export

	DOMWriter = New DOMWriter;

	TempFile = FileName + ".tmp";

	XMLWriter = New XMLWriter;
	XMLWriter.OpenFile(TempFile);
	DOMWriter.Write(Document, XMLWriter);
	XMLWriter.Close();

	MoveFile(TempFile, FileName);

EndProcedure

Function TechnologicalLog_ConsoleLogExists() Export

	TLConfigFile = TechnologicalLog_GetAppConfigurationFolder()
		+ GetServerPathSeparator() + "logcfg.xml";
	ConfigFile = New Файл(TLConfigFile);

	If ConfigFile.Exists() Then

		Document = TechnologicalLog_ReadDOM(TLConfigFile);

		If TechnologicalLog_DOM_TLConfig(Document) Then

			Label = TechnologicalLog_ConsoleLabel();
			LabelExists = False;
			For Each Node In Document.FirstChild.ChildNodes Do

				If LabelExists Then
					LogLocationAttribute = Node.Attributes.GetNamedItem("location");
					If LogLocationAttribute <> Undefined Then
						TechLogFolder = LogLocationAttribute.Value;
						Return True;
					EndIf;
				EndIf;

				Если Node.NodeName = "#comment" And TrimAll(Node.NodeValue) = Label Then
					LabelExists = True;
				EndIf;

			EndDo;

		EndIf;

	EndIf;

	Return False;

EndFunction

Procedure TechnologicalLog_AppendConsoleLog(TLPath) Export

	TLConfigFile = TechnologicalLog_GetAppConfigurationFolder()
		+ GetServerPathSeparator() + "logcfg.xml";
	ConfigFile = New File(TLConfigFile);

	If ConfigFile.Exists() Then

		Document = TechnologicalLog_ReadDOM(TLConfigFile);

		If TechnologicalLog_DOM_TLConfig(Document) Then

			TechnologicalLog_RemoveConsloleLogFromDOM(Document);

			TLConfigTemplate = GetTemplate("TLConfigTemplate");
			Reader = New XMLReader;
			Reader.SetString(StrTemplate(TLConfigTemplate.GetText(), TechnologicalLog_ConsoleLabel(),
				TLPath, UserName()));
			Builder = New DOMBuilder;
			logcfg = Builder.Read(Reader);

			For Each SourceNode In logcfg.FirstChild.ChildNodes Do
				Node = Document.ImportNode(SourceNode, True);
				Document.FirstChild.AppendChild(Node);
			EndDo;

			TechnologicalLog_WriteDOM(Document, TLConfigFile);
			TechLogFolder = TLPath;

		EndIf;

	Else
		Raise NSTR("ru = 'logcfg не найден'; en = 'logcfg not found'");
	EndIf;

EndProcedure

Function TechnologicalLog_ReadDOM(ИмяФайла) Экспорт
	Чтение = Новый ЧтениеXML;
	Чтение.ОткрытьФайл(ИмяФайла);
	Построитель = Новый ПостроительDOM;
	Возврат Построитель.Прочитать(Чтение);
EndFunction

Procedure ТехнологическийЖурнал_УдалитьЛогКонсоли() Экспорт

	ФайлКонфигурацииТЖ = TechnologicalLog_GetAppConfigurationFolder()
		+ ПолучитьРазделительПутиСервера() + "logcfg.xml";
	ФайлКонфигурации = Новый Файл(ФайлКонфигурацииТЖ);

	Если ФайлКонфигурации.Существует() Тогда

		Документ = TechnologicalLog_ReadDOM(ФайлКонфигурацииТЖ);

		Если TechnologicalLog_DOM_TLConfig(Документ) Тогда

			TechnologicalLog_RemoveConsloleLogFromDOM(Документ);

			TechnologicalLog_WriteDOM(Документ, ФайлКонфигурацииТЖ);

		EndIf;

	EndIf;

EndProcedure

Function ВыполнитьТестовыйЗапрос()

	Если Не ЗначениеЗаполнено(SessionLabel) Тогда
		SessionLabel = Строка(Новый УникальныйИдентификатор);
	EndIf;

	ТестовыйЗапрос = Новый Запрос("ВЫБРАТЬ """ + SessionLabel + """");
	ТестовыйЗапрос.Выполнить(); //6345bb7034de4ad1b14249d2d7ac26dd

EndFunction

Function ТехнологическийЖурнал_Включился() Экспорт

	ВыполнитьТестовыйЗапрос();

	маФайлы = НайтиФайлы(TechLogFolder, "*.log", Истина);
	Если маФайлы.Количество() > 0 Тогда

		Для Каждого ФайлЖурнала Из маФайлы Цикл

			Если Найти(ФайлЖурнала.Путь, "rphost_") = 0 Тогда
				Продолжить;
			EndIf;

			Чтение = Новый ЧтениеДанных(ФайлЖурнала.ПолноеИмя);

			Если Чтение.ПропуститьДо(SessionLabel) = 0 Тогда
				TechLogEnabled = Истина;
				Возврат Истина;
			EndIf;

		EndDo;

	EndIf;

	ВыполнитьТестовыйЗапрос();

	Возврат Ложь;

EndFunction

Function ТехнологическийЖурнал_Выключился() Экспорт

	Попытка
		УдалитьФайлы(TechLogFolder);
	Исключение
		Возврат Ложь;
	КонецПопытки;

	TechLogEnabled = Ложь;
	Возврат Истина;

EndFunction

Procedure ТехнологическийЖурнал_Включить() Экспорт

	ПутьТЖ = КаталогВременныхФайлов() + LockedQueriesExtension;

	й = 1;
	Пока Истина Цикл

		Файл = Новый Файл(ПутьТЖ);

		Если Файл.Существует() Тогда
			Попытка
				УдалитьФайлы(Файл.ПолноеИмя);
			Исключение
			КонецПопытки;
		EndIf;

		Если Не Файл.Существует() Тогда
			Прервать;
		EndIf;
		
		//Не удается удалить каталог. Возможно, ТЖ еще не выключен.
		//Придется использовать другой, иначе будет невозможно контролировать включение.
		//Текущий каталог с логами очиститься при следующем "нормальном" включении.
		ПутьТЖ = КаталогВременныхФайлов() + LockedQueriesExtension + й;
		й = й + 1;

	EndDo;

	TechnologicalLog_AppendConsoleLog(ПутьТЖ);

	SessionLabel = Строка(Новый УникальныйИдентификатор);
	ВыполнитьТестовыйЗапрос();

EndProcedure

Procedure ТехнологическийЖурнал_Выключить() Экспорт
	ТехнологическийЖурнал_УдалитьЛогКонсоли();
EndProcedure

Function ТехнологическийЖурнал_ПолучитьФрагментЖурналаПоИдентификаторуИВремени(Идентификатор, ВремяНачалаЗапроса,
	ВремяОкончанияЗапроса) Экспорт

	маЛоги = НайтиФайлы(TechLogFolder, "rphost*");

	маРезультат = Новый Массив;
	фФрагментНайден = Ложь;
	Для Каждого Лог Из маЛоги Цикл

		ВремяПоиска = ВремяНачалаЗапроса;

		Пока Не фФрагментНайден И ВремяПоиска < ВремяОкончанияЗапроса Цикл

			ИмяФайлаЛога = Формат(ВремяПоиска, "ДФ=ггММддЧЧ.log");
			ВремяПоиска = ВремяПоиска + 60 * 60;
			ПолноеИмяФайлаЛога = СтрШаблон("%1%2%3", Лог.ПолноеИмя, ПолучитьРазделительПутиСервера(), ИмяФайлаЛога);

			Файл = Новый Файл(ПолноеИмяФайлаЛога);
			Если Не Файл.Существует() Тогда
				Продолжить;
			EndIf;

			Чтение = Новый ЧтениеДанных(ПолноеИмяФайлаЛога);

			Если Не фФрагментНайден Тогда
				Если Чтение.ПропуститьДо(Идентификатор + "_begin") = 0 Тогда
					фФрагментНайден = Истина;
				EndIf;
			EndIf;

			Если фФрагментНайден Тогда

				РезультатЧтенияЖурнала = Чтение.ПрочитатьДо(Идентификатор + "_end");
				маРезультат.Добавить(РезультатЧтенияЖурнала);

				Если РезультатЧтенияЖурнала.МаркерНайден Тогда
					Прервать;
				EndIf;

			EndIf;

		EndDo;

		Если фФрагментНайден Тогда
			Прервать;
		EndIf;

	EndDo;

	Если маРезультат.Количество() = 0 Тогда
		Возврат Неопределено;
	EndIf;

	маРезультатСтроки = Новый Массив;
	Для Каждого РезультатЧтения Из маРезультат Цикл
		Чтение = Новый ЧтениеТекста(РезультатЧтения.ОткрытьПотокДляЧтения(), КодировкаТекста.UTF8);
		маРезультатСтроки.Добавить(Чтение.Прочитать());
	EndDo;

	Возврат СтрСоединить(маРезультатСтроки, "
											|");

EndFunction

Function ТехнологическийЖурнал_ПолучитьИнформациюПоЗапросу(Идентификатор, ВремяНачалаЗапроса, ДлительностьЗапроса) Экспорт

	Если Не ЗначениеЗаполнено(TechLogFolder) Тогда
		Возврат Неопределено;
	EndIf;

	ВремяОкончанияЗапроса = ВремяНачалаЗапроса + ДлительностьЗапроса;
	ВремяПоискаНачало = МестноеВремя('00010101' + ВремяНачалаЗапроса / 1000);
	ВремяПоискаКонец = МестноеВремя('00010101' + ВремяОкончанияЗапроса / 1000 + 1);

	ФрагментЖурнала = ТехнологическийЖурнал_ПолучитьФрагментЖурналаПоИдентификаторуИВремени(Идентификатор,
		ВремяПоискаНачало, ВремяПоискаКонец);

	Возврат ФрагментЖурнала;

EndFunction

#EndRegion

#Region СохраняемыеСостояния

//Сохраняемые состояния - структура, предназначена для сохранения значений, которых нет в опциях (состояния флажков форм,
//разных значений, и т.д.). Записывается в файл. Из файла читается только при первом открытии.

Procedure СохраняемыеСостояния_Сохранить(ИмяЗначения, Значение) Экспорт
	SavedStates.Вставить(ИмяЗначения, Значение);
EndProcedure

Function СохраняемыеСостояния_Получить(ИмяЗначения, ЗначениеПоУмолчанию) Экспорт
	Перем Значение;

	Если Не SavedStates.Свойство(ИмяЗначения, Значение) Тогда
		Возврат ЗначениеПоУмолчанию;
	EndIf;

	Возврат Значение;

EndFunction

#EndRegion

#Region ИнтерфейсСТаблицейЗначений

//Описание типов внутри содержит больше, чем это можно увидеть средствами языка.
//Например, там есть какая-то информация, которая прилетает туда из "определяемых типов" полей в запросе.
//Это приводит к некорректному поведению. Колонка не воспринимала отрицательные числа, хотя в типе точно стаяло в квалификаторах числа знак "Любой".
//Эта Function пересоздает описание типов, что бы там внутри не было ничего лишнего.
Function НормализоватьТип(НекоеОписаниеТипов)

	Типы = НекоеОписаниеТипов.Типы();
	НовоеОписаниеТипов = Новый ОписаниеТипов(Типы, НекоеОписаниеТипов.КвалификаторыЧисла,
		НекоеОписаниеТипов.КвалификаторыСтроки, НекоеОписаниеТипов.КвалификаторыДаты);

	Возврат НовоеОписаниеТипов;

EndFunction

Procedure СоздатьРеквизитыТаблицыПоКолонкам(Форма, ИмяРеквизитаТаблицыФормы, ИмяРеквизитаСоответствияКолонок,
	ИмяРеквизитаКолонкиКонтейнера, Колонки, фДляРедактирования = Ложь, стМакроколонки = Неопределено) Экспорт

	маНеотображаемыеТипы = GetTypesUndisplayableAtClient();

	ИмяРеквизитаТаблицыФормыИтоги = ИмяРеквизитаТаблицыФормы + "Итоги";
	ЕстьИтоги = Ложь;
	Для Каждого Реквизит Из Форма.ПолучитьРеквизиты() Цикл
		Если Реквизит.Имя = ИмяРеквизитаТаблицыФормыИтоги Тогда
			ЕстьИтоги = Истина;
			Прервать;
		EndIf;
	EndDo;

	маУдаляемыеРеквизиты = Новый Массив;

	Если ТипЗнч(Форма[ИмяРеквизитаТаблицыФормы]) = Тип("ДанныеФормыКоллекция") Тогда
		Форма[ИмяРеквизитаТаблицыФормы].Очистить();
	EndIf;

	Для Каждого Реквизит Из Форма.ПолучитьРеквизиты(ИмяРеквизитаТаблицыФормы) Цикл
		маУдаляемыеРеквизиты.Добавить(Реквизит.Путь + "." + Реквизит.Имя);
	EndDo;

	Если ЕстьИтоги Тогда
		Форма[ИмяРеквизитаТаблицыФормыИтоги].Очистить();
		Для Каждого Реквизит Из Форма.ПолучитьРеквизиты(ИмяРеквизитаТаблицыФормыИтоги) Цикл
			маУдаляемыеРеквизиты.Добавить(Реквизит.Путь + "." + Реквизит.Имя);
		EndDo;
	EndIf;

	стКолонкиКонтейнера = Новый Структура;
	маДобавляемыеРеквизиты = Новый Массив;
	Если Колонки <> Неопределено Тогда

		Для Каждого Колонка Из Колонки Цикл

			стМакроколонка = Неопределено;
			Если стМакроколонки <> Неопределено И стМакроколонки.Свойство(Колонка.Имя, стМакроколонка) Тогда
				ТипКолонки = стМакроколонка.ТипЗначения;
			Иначе
				ТипКолонки = Колонка.ТипЗначения;
			EndIf;

			ЕстьНеотображаемыеТипы = Ложь;
			Для Каждого НеотображаемыйТип Из маНеотображаемыеТипы Цикл
				Если ТипКолонки.СодержитТип(НеотображаемыйТип) Тогда
					ЕстьНеотображаемыеТипы = Истина;
					Прервать;
				EndIf;
			EndDo;

			Если ЕстьНеотображаемыеТипы Тогда

				ИмяКолонкиКонтейнера = Колонка.Имя + СуффиксРеквизитаКонтейнера();
				Реквизит = Новый РеквизитФормы(ИмяКолонкиКонтейнера, Новый ОписаниеТипов, ИмяРеквизитаТаблицыФормы,
					ИмяКолонкиКонтейнера);
				маДобавляемыеРеквизиты.Добавить(Реквизит);
				стКолонкиКонтейнера.Вставить(Колонка.Имя, ТипКолонки);

				ТипКолонкиТаблицы = Новый ОписаниеТипов(ТипКолонки, "Строка", маНеотображаемыеТипы);

			Иначе
				ТипКолонкиТаблицы = НормализоватьТип(ТипКолонки);
			EndIf;

			Если ТипКолонкиТаблицы.СодержитТип(Тип("Число")) Тогда
				ТипКолонкиИтогов = Новый ОписаниеТипов("Число", ТипКолонкиТаблицы.КвалификаторыЧисла);
			Иначе
				ТипКолонкиИтогов = Новый ОписаниеТипов("Null");
			EndIf;

			Реквизит = Новый РеквизитФормы(Колонка.Имя, ТипКолонкиТаблицы, ИмяРеквизитаТаблицыФормы, Колонка.Имя);
			маДобавляемыеРеквизиты.Добавить(Реквизит);

			Если ЕстьИтоги Тогда
				Реквизит = Новый РеквизитФормы(Колонка.Имя, ТипКолонкиИтогов, ИмяРеквизитаТаблицыФормыИтоги,
					Колонка.Имя);
				маДобавляемыеРеквизиты.Добавить(Реквизит);
			EndIf;

		EndDo;

	EndIf;

	Форма.ИзменитьРеквизиты(маДобавляемыеРеквизиты, маУдаляемыеРеквизиты);

	Если ЕстьИтоги Тогда
		Форма[ИмяРеквизитаТаблицыФормыИтоги].Добавить();
	EndIf;

	Пока Форма.Элементы[ИмяРеквизитаТаблицыФормы].ПодчиненныеЭлементы.Количество() > 0 Цикл
		Форма.Элементы.Удалить(Форма.Элементы[ИмяРеквизитаТаблицыФормы].ПодчиненныеЭлементы[0]);
	EndDo;

	стКолонкиРезультата = Новый Структура;
	Если Колонки <> Неопределено Тогда

		Для Каждого Колонка Из Колонки Цикл

			ИмяКолонки = ИмяРеквизитаТаблицыФормы + Колонка.Имя;
			стКолонкиРезультата.Вставить(ИмяКолонки, Колонка.Имя);
			КолонкаТаблицы = Форма.Элементы.Добавить(ИмяКолонки, Тип("ПолеФормы"),
				Форма.Элементы[ИмяРеквизитаТаблицыФормы]);
			КолонкаТаблицы.ПутьКДанным = ИмяРеквизитаТаблицыФормы + "." + Колонка.Имя;

			Если ЕстьИтоги Тогда
				КолонкаТаблицы.ПутьКДаннымПодвала = ИмяРеквизитаТаблицыФормыИтоги + "[0]." + Колонка.Имя;
			EndIf;

			Если фДляРедактирования Тогда

				КолонкаТаблицы.Вид = ВидПоляФормы.ПолеВвода;
				КолонкаТаблицы.РежимРедактирования = РежимРедактированияКолонки.Непосредственно;
				КолонкаТаблицы.КнопкаОчистки = Истина;

				Если стКолонкиКонтейнера.Свойство(Колонка.Имя) Тогда
					КолонкаТаблицы.КнопкаВыбора = Истина;
					КолонкаТаблицы.РедактированиеТекста = Ложь;
					КолонкаТаблицы.УстановитьДействие("НачалоВыбора", "ПолеТаблицыНачалоВыбора");
				EndIf;

			EndIf;

		EndDo;

	EndIf;

	Форма[ИмяРеквизитаСоответствияКолонок] = стКолонкиРезультата;
	Форма[ИмяРеквизитаКолонкиКонтейнера] = стКолонкиКонтейнера;

EndProcedure

Procedure ИнициализироватьКонтейнерыСтрокиПоТипам(СтрокаТаблицы, ТаблицаЗначенийКолонкиКонтейнера) Экспорт

	Для Каждого кз Из ТаблицаЗначенийКолонкиКонтейнера Цикл

		ИмяКолонки = кз.Ключ;
		ТипЗначения = кз.Значение;
		маТипыЗначения = ТипЗначения.Типы();

		Контейнер = Неопределено;
		Если маТипыЗначения.Количество() = 1 Тогда

			Если ТипЗначения.СодержитТип(Тип("Тип")) Тогда
				Контейнер = Контейнер_СохранитьЗначение(Тип("Неопределено"));
			ИначеЕсли ТипЗначения.СодержитТип(Тип("МоментВремени")) Тогда
				Контейнер = Контейнер_СохранитьЗначение(Новый МоментВремени('00010101', Неопределено));
			EndIf;

		EndIf;

		Если Не ЗначениеЗаполнено(Контейнер) Тогда
			Контейнер = ПустойКонтейнер();
		EndIf;

		СтрокаТаблицы[ИмяКолонки + СуффиксРеквизитаКонтейнера()] = Контейнер;

	EndDo;

EndProcedure

Function ПустойКонтейнер()
	Возврат Новый Структура("Тип, Представление", , "???");
EndFunction

//Контейнеры в таблице должны быть всегда.
//Если контейнер не нужен, и значение храниться в основном поле - добавляем пустой контейнер.
Procedure ДобавитьКонтейнеры(СтрокаТаблицыЗначенийРеквизита, СтрокаИсточник, КолонкиКонтейнера) Экспорт

	Для Каждого кз Из КолонкиКонтейнера Цикл

		ИмяКолонки = кз.Ключ;
		ИмяКолонкиКонтейнера = ИмяКолонки + СуффиксРеквизитаКонтейнера();

		Если ТипЗнч(СтрокаИсточник[ИмяКолонки]) = Тип("РезультатЗапроса") Тогда
			Контейнер = Контейнер_СохранитьЗначение(СтрокаИсточник[кз.Ключ].Выгрузить());
		Иначе
			Контейнер = Контейнер_СохранитьЗначение(СтрокаИсточник[кз.Ключ]);
		EndIf;

		Если ТипЗнч(Контейнер) <> Тип("Структура") Тогда
			Контейнер = ПустойКонтейнер();
		Иначе
			СтрокаТаблицыЗначенийРеквизита[ИмяКолонки] = Контейнер.Представление;
		EndIf;

		СтрокаТаблицыЗначенийРеквизита[ИмяКолонкиКонтейнера] = Контейнер;

	EndDo;

EndProcedure

Function ТаблицаВРеквизитыФормы(ТаблицаЗначений, ТаблицаЗначенийРеквизит, ТаблицаЗначенийКолонкиКонтейнераРеквизит) Экспорт

	фЕстьКонтейнеры = ТаблицаЗначенийКолонкиКонтейнераРеквизит.Количество() > 0;
	Если Не фЕстьКонтейнеры Тогда
		ТаблицаЗначенийРеквизит.Загрузить(ТаблицаЗначений);
	Иначе

		Для Каждого Строка Из ТаблицаЗначений Цикл
			СтрокаТаблицыЗначенийРеквизита = ТаблицаЗначенийРеквизит.Добавить();
			ЗаполнитьЗначенияСвойств(СтрокаТаблицыЗначенийРеквизита, Строка);
			Если фЕстьКонтейнеры Тогда
				ДобавитьКонтейнеры(СтрокаТаблицыЗначенийРеквизита, Строка, ТаблицаЗначенийКолонкиКонтейнераРеквизит);
			EndIf;
		EndDo;

	EndIf;

EndFunction

Function ТаблицаИзРеквизитовФормы(ТаблицаЗначенийРеквизит, ТаблицаЗначенийКолонкиКонтейнераРеквизит) Экспорт

	тзДанные = ТаблицаЗначенийРеквизит.Выгрузить();

	Если ТаблицаЗначенийКолонкиКонтейнераРеквизит.Количество() = 0 Тогда
		Возврат Контейнер_СохранитьЗначение(тзДанные);
	EndIf;

	стИменаКолонокКонтейнеров = Новый Структура;
	Для Каждого кз Из ТаблицаЗначенийКолонкиКонтейнераРеквизит Цикл
		стИменаКолонокКонтейнеров.Вставить(кз.Ключ + СуффиксРеквизитаКонтейнера());
	EndDo;

	тзВозвращаемаяТаблица = Новый ТаблицаЗначений;
	Для Каждого Колонка Из тзДанные.Колонки Цикл

		Если стИменаКолонокКонтейнеров.Свойство(Колонка.Имя) Тогда
			Продолжить;
		EndIf;

		ТипКолонки = Колонка.ТипЗначения;
		ТаблицаЗначенийКолонкиКонтейнераРеквизит.Свойство(Колонка.Имя, ТипКолонки);
		тзВозвращаемаяТаблица.Колонки.Добавить(Колонка.Имя, ТипКолонки);
		
	EndDo
	;

	чКоличествоСтрок = тзДанные.Количество();
	Для Каждого СтрокаТаблицыЗначенийРеквизита Из ТаблицаЗначенийРеквизит Цикл
		Строка = тзВозвращаемаяТаблица.Добавить();
		ЗаполнитьЗначенияСвойств(Строка, СтрокаТаблицыЗначенийРеквизита);
		Для Каждого кз Из ТаблицаЗначенийКолонкиКонтейнераРеквизит Цикл
			ИмяКолонки = кз.Ключ;
			Строка[ИмяКолонки] = Контейнер_ВосстановитьЗначение(СтрокаТаблицыЗначенийРеквизита[ИмяКолонки
				+ СуффиксРеквизитаКонтейнера()]);
		EndDo;
	EndDo;

	Возврат Контейнер_СохранитьЗначение(тзВозвращаемаяТаблица);

EndFunction

#EndRegion

#Region Контейнер

//Таблица значений может быть как есть, либо уже сериализованная и положенная в структуру-контейнер.
//Контейнер для параметров и для таблиц имеет немного разное значение.
//Для параметра: там может лежать либо само значение, либо структура для списка значений, массива или специального типа.
//Для таблицы: всегда структура для специального типа.

Function СуффиксРеквизитаКонтейнера() Экспорт
	Возврат "_31415926Контейнер";
EndFunction

Function Контейнер_Очистить(Контейнер) Экспорт

	Если Контейнер.Тип = "ТаблицаЗначений" Тогда
		Значение = Контейнер_ВосстановитьЗначение(Контейнер);
		Значение.Очистить();
	ИначеЕсли Контейнер.Тип = "СписокЗначений" Тогда
		Значение = Контейнер_ВосстановитьЗначение(Контейнер);
		Значение.Очистить();
	ИначеЕсли Контейнер.Тип = "Массив" Тогда
		Значение = Новый Массив;
	ИначеЕсли Контейнер.Тип = "Тип" Тогда
		Значение = Тип("Неопределено");
	ИначеЕсли Контейнер.Тип = "Граница" Тогда
		Значение = Новый Граница(, ВидГраницы.Включая);
	ИначеЕсли Контейнер.Тип = "МоментВремени" Тогда
		Значение = Новый МоментВремени('00010101');
	ИначеЕсли Контейнер.Тип = "ХранилищеЗначения" Тогда
		Значение = Новый ХранилищеЗначения(Неопределено);
	Иначе
		ВызватьИсключение "Неизвестный тип контейнера";
	EndIf;

	Контейнер_СохранитьЗначение(Значение);

EndFunction

Function Контейнер_СохранитьЗначение(Значение) Экспорт

	ТипЗначения = ТипЗнч(Значение);
	Если ТипЗначения = Тип("Граница") Тогда
		Результат = Новый Структура("Тип, ВидГраницы, Значение, Представление", "Граница");
		ЗаполнитьЗначенияСвойств(Результат, Значение);
		Результат.ВидГраницы = Строка(Результат.ВидГраницы);
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("МоментВремени") Тогда
		Результат = Новый Структура("Тип, Дата, Ссылка, Представление", "МоментВремени");
		ЗаполнитьЗначенияСвойств(Результат, Значение);
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("Тип") Тогда
		Результат = Новый Структура("Тип, ИмяТипа, Представление", "Тип", GetTypeName(Значение));
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("ХранилищеЗначения") Тогда
		Результат = Новый Структура("Тип, Хранилище, Представление", "ХранилищеЗначения", ValueToString(Значение));
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("Массив") Тогда
		Результат = Новый Структура("Тип, СписокЗначений, Представление", "Массив", ValueListFromArray(Значение));
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("СписокЗначений") Тогда
		Результат = Новый Структура("Тип, СписокЗначений, Представление", "СписокЗначений", Значение);
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	ИначеЕсли ТипЗначения = Тип("ТаблицаЗначений") Тогда
		Результат = Новый Структура("Тип, КоличествоСтрок, Значение, Представление", "ТаблицаЗначений",
			Значение.Количество(), ValueToString(Значение));
		Результат.Представление = Контейнер_ПолучитьПредставление(Результат);
	Иначе
		Результат = Значение;
	EndIf;

	Возврат Результат;

EndFunction

Function Контейнер_ВосстановитьЗначение(СохраненноеЗначение) Экспорт

	Если ТипЗнч(СохраненноеЗначение) = Тип("Структура") Тогда
		Если СохраненноеЗначение.Тип = "Граница" Тогда
			Результат = Новый Граница(СохраненноеЗначение.Значение, ВидГраницы[СохраненноеЗначение.ВидГраницы]);
		ИначеЕсли СохраненноеЗначение.Тип = "МоментВремени" Тогда
			Результат = Новый МоментВремени(СохраненноеЗначение.Дата, СохраненноеЗначение.Ссылка);
		ИначеЕсли СохраненноеЗначение.Тип = "МоментВремени" Тогда
			Результат = СохраненноеЗначение.УникальныйИдентификатор;
		ИначеЕсли СохраненноеЗначение.Тип = "Тип" Тогда
			Результат = Тип(СохраненноеЗначение.ИмяТипа);
		ИначеЕсли СохраненноеЗначение.Тип = "СписокЗначений" Тогда
			Результат = СохраненноеЗначение.СписокЗначений;
		ИначеЕсли СохраненноеЗначение.Тип = "Массив" Тогда
			Результат = СохраненноеЗначение.СписокЗначений.ВыгрузитьЗначения();
		ИначеЕсли СохраненноеЗначение.Тип = "ТаблицаЗначений" Тогда
			Результат = StringToValue(СохраненноеЗначение.Значение);
		EndIf;
	Иначе
		Результат = СохраненноеЗначение;
	EndIf;

	Возврат Результат;

EndFunction

Function Контейнер_ПолучитьПредставление(Контейнер) Экспорт

	чРазмерПредставления = 200;

	Если ТипЗнч(Контейнер) = Тип("Структура") Тогда
		Если Контейнер.Тип = "Граница" Тогда
			Возврат Строка(Контейнер.Значение) + " " + Контейнер.ВидГраницы;
		ИначеЕсли Контейнер.Тип = "Массив" Тогда
			Возврат Лев(СтрСоединить(Контейнер.СписокЗначений.ВыгрузитьЗначения(), "; "), чРазмерПредставления);
		ИначеЕсли Контейнер.Тип = "СписокЗначений" Тогда
			Возврат Лев(СтрСоединить(Контейнер.СписокЗначений.ВыгрузитьЗначения(), "; "), чРазмерПредставления);
		ИначеЕсли Контейнер.Тип = "ТаблицаЗначений" Тогда
			КоличествоСтрок = Неопределено;
			Если Контейнер.Свойство("КоличествоСтрок", КоличествоСтрок) Тогда
				Возврат "<строк: " + КоличествоСтрок + ">";
			Иначе
				Возврат "<строк: ?>";
			EndIf;
		ИначеЕсли Контейнер.Тип = "МоментВремени" Тогда
			Возврат Строка(Контейнер.Дата) + "; " + Контейнер.Ссылка;
		ИначеЕсли Контейнер.Тип = "Тип" Тогда
			Возврат "Тип: " + Тип(Контейнер.ИмяТипа);
		ИначеЕсли Контейнер.Тип = "ХранилищеЗначения" Тогда
			Возврат "<ХранилищеЗначения>";
		EndIf;
	Иначе
		Возврат "???";
	EndIf;

EndFunction

#EndRegion

Function СохранитьЗапрос(СеансИД, Запрос) Экспорт

	Если ТипЗнч(СеансИД) <> Тип("Число") Тогда
		Возврат "!Не верный тип параметра 1: " + ТипЗнч(СеансИД) + ". Должен быть тип ""Число""";
	EndIf;

	Если ТипЗнч(Запрос) <> Тип("Запрос") Тогда
		Возврат "!Не верный тип параметра 2: " + ТипЗнч(Запрос) + ". Должен быть тип ""Запрос""";
	EndIf;

	Initializing( , СеансИД);

	ИмяФайла = ПолучитьИмяВременногоФайла(LockedQueriesExtension);

	ВременныеТаблицы = Новый Массив;

	Если Запрос.МенеджерВременныхТаблиц <> Неопределено Тогда
		Для Каждого Таблица Из Запрос.МенеджерВременныхТаблиц.Таблицы Цикл

			ВременнаяТаблица = Новый ТаблицаЗначений;
			Для Каждого Колонка Из Таблица.Колонки Цикл
				ВременнаяТаблица.Колонки.Добавить(Колонка.Имя, Колонка.ТипЗначения);
			EndDo;

			выбТаблица = Таблица.ПолучитьДанные().Выбрать();
			Пока выбТаблица.Следующий() Цикл
				ЗаполнитьЗначенияСвойств(ВременнаяТаблица.Добавить(), выбТаблица);
			EndDo;

			ВременныеТаблицы.Добавить(
				Новый Структура("Имя, Таблица", Таблица.ПолноеИмя, ВременнаяТаблица));
		EndDo;
	EndIf;

	Структура = Новый Структура("Текст, Параметры, ВременныеТаблицы", , , ВременныеТаблицы);
	ЗаполнитьЗначенияСвойств(Структура, Запрос);
	ЗаписьXML = Новый ЗаписьXML;
	ЗаписьXML.ОткрытьФайл(ИмяФайла);
	СериализаторXDTO.ЗаписатьXML(ЗаписьXML, Структура, НазначениеТипаXML.Явное);

	ЗаписьXML.Закрыть();

	Возврат "ОК:";// + ИмяФайла;

EndFunction

//&НаСервереБезКонтекста
Function ВыполнитьКод(ЭтотКод, Выборка, Параметры, ПризнакПрогресса)
	Выполнить (ЭтотКод);
EndFunction

//Этот метод можно использовать в коде для отображения прогресса.
//Параметры:
//	Обработано - число, количество обработанных записей.
//	КоличествоВсего - число, количество записей в выборке всего.
//	ДатаНачалаВМиллисекундах - число, дата начала обработки, полученное с помощью ТекущаяУниверсальнаяДатаВМиллисекундах()
//		в момент начала обработки. Это значение необходимо корректного расчета оставшегося времени.
//	ПризнакПрогресса - строка, специальное значение, необходимое для передачи значений прогресса на клиент.
//		Это значение необходимо просто передать в параметр без изменений.
Function СообщитьПрогресс(Обработано, КоличествоВсего, ДатаНачалаВМиллисекундах, ПризнакПрогресса)
	ДатаВМиллисекундах = ТекущаяУниверсальнаяДатаВМиллисекундах();
	Сообщить(ПризнакПрогресса + ValueToString(Новый Структура("Прогресс, ДлительностьНаМоментПрогресса", Обработано
		* 100 / КоличествоВсего, ДатаВМиллисекундах - ДатаНачалаВМиллисекундах)));
	Возврат ДатаВМиллисекундах;
EndFunction

Procedure ВыполнитьАлгоритмПользователя(ПараметрыВыполнения, АдресРезультата) Экспорт

	стРезультатЗапроса = ПараметрыВыполнения[0];
	маРезультатЗапроса = стРезультатЗапроса.Результат;
	ПараметрыЗапроса = стРезультатЗапроса.Параметры;
	РезультатВПакете = ПараметрыВыполнения[1];
	Код = ПараметрыВыполнения[2];
	ФлагПострочно = ПараметрыВыполнения[3];
	ИнтервалОбновленияВыполненияАлгоритма = ПараметрыВыполнения[4];

	стРезультат = маРезультатЗапроса[Число(РезультатВПакете) - 1];
	рзВыборка = стРезультат.Результат;
	Выборка = рзВыборка.Выбрать();
	ДатаНачалаВМиллисекундах = ТекущаяУниверсальнаяДатаВМиллисекундах();

	Если ФлагПострочно Тогда

		КоличествоВсего = Выборка.Количество();
		чМоментОкончанияПорции = 0;
		й = 0;
		Пока Выборка.Следующий() Цикл

			ВыполнитьКод(Код, Выборка, ПараметрыЗапроса, АдресРезультата);

			й = й + 1;
			Если ТекущаяУниверсальнаяДатаВМиллисекундах() >= чМоментОкончанияПорции Тогда
				//Будем использовать АдресРезультата в качестве метки сообщения состояния - это очень уникальное значение.
				ДатаВМиллисекундах = СообщитьПрогресс(й, КоличествоВсего, ДатаНачалаВМиллисекундах, АдресРезультата);
				чМоментОкончанияПорции = ДатаВМиллисекундах + ИнтервалОбновленияВыполненияАлгоритма;
			EndIf;

		EndDo;

	Иначе
		ВыполнитьКод(Код, Выборка, ПараметрыЗапроса, АдресРезультата);
	EndIf;

EndProcedure

#Region ПланЗапроса

Function СтруктураХранения()

	тзСтруктура = ПолучитьИзВременногоХранилища(IBStorageStructure);

	Если тзСтруктура = Неопределено Тогда
		тзСтруктура = ПолучитьСтруктуруХраненияБазыДанных( , Истина);
		тзСтруктура.Индексы.Добавить("Метаданные");
		ПоместитьВоВременноеХранилище(тзСтруктура, IBStorageStructure);
	EndIf;

	Возврат тзСтруктура;

EndFunction

Procedure SQLЗапросВТермины1С_ДобавитьТермин(ДанныеТерминов, ИмяБД, Имя1С)
	Если Не ПустаяСтрока(Имя1С) Тогда
		СтрокаДанныхТерминов = ДанныеТерминов.Добавить();
		СтрокаДанныхТерминов.ИмяБД = ИмяБД;
		СтрокаДанныхТерминов.Имя1С = Имя1С;
		СтрокаДанныхТерминов.ДлиннаИмениБД = СтрДлина(СтрокаДанныхТерминов.ИмяБД);
	EndIf;
EndProcedure

Function SQLЗапросВТермины1С(ТекстЗапросаSQL, ДанныеТерминов = Неопределено) Экспорт

	тзСтруктура = СтруктураХранения();

	Если ДанныеТерминов = Неопределено Тогда

		ТипСтрока = Новый ОписаниеТипов("Строка");
		ДанныеТерминов = Новый ТаблицаЗначений;
		ДанныеТерминов.Колонки.Добавить("ИмяБД", ТипСтрока);
		ДанныеТерминов.Колонки.Добавить("Имя1С", ТипСтрока);
		ДанныеТерминов.Колонки.Добавить("ДлиннаИмениБД", Новый ОписаниеТипов("Число"));

		Для Каждого Строка Из тзСтруктура Цикл

			ъ = Найти(ТекстЗапросаSQL, Строка.ИмяТаблицыХранения);
			Если ъ > 0 Тогда

				SQLЗапросВТермины1С_ДобавитьТермин(ДанныеТерминов, Строка.ИмяТаблицыХранения, Строка.ИмяТаблицы);

				Для Каждого СтрокаПоля Из Строка.Поля Цикл
					SQLЗапросВТермины1С_ДобавитьТермин(ДанныеТерминов, СтрокаПоля.ИмяПоляХранения, СтрокаПоля.ИмяПоля);
				EndDo;

			EndIf;

		EndDo;

		ДанныеТерминов.Сортировать("ДлиннаИмениБД Убыв");

	EndIf;

	ТекстЗапросаВТерминах1С = ТекстЗапросаSQL;

	Для Каждого Строка Из ДанныеТерминов Цикл
		ТекстЗапросаВТерминах1С = СтрЗаменить(ТекстЗапросаВТерминах1С, Строка.ИмяБД, Строка.Имя1С);
	EndDo;

	Возврат ТекстЗапросаВТерминах1С;

EndFunction

//	РегистрТерминов - преобразование регистра терминов:
//		0 - не преобразовывать данные терминов
//		1 - данные терминов преобразовать в нижний регистр (для POSTGRS)
Function SQLПланВТермины1С(ПланЗапроса, ДанныеТерминов, РегистрТерминов = 0) Экспорт

	ПланЗапросаВТерминах1С = ПланЗапроса;

	Если РегистрТерминов = 1 Тогда
		Для Каждого Строка Из ДанныеТерминов Цикл
			ПланЗапросаВТерминах1С = СтрЗаменить(ПланЗапросаВТерминах1С, НРег(Строка.ИмяБД), Строка.Имя1С);
		EndDo;
	Иначе
		Для Каждого Строка Из ДанныеТерминов Цикл
			ПланЗапросаВТерминах1С = СтрЗаменить(ПланЗапросаВТерминах1С, Строка.ИмяБД, Строка.Имя1С);
		EndDo;
	EndIf;

	Возврат ПланЗапросаВТерминах1С;

EndFunction

#EndRegion

#Region СведенияОВнешнейОбработке

Function СведенияОВнешнейОбработке() Экспорт

	Initializing();

	ПараметрыРегистрации = Новый Структура;
	ПараметрыРегистрации.Вставить("Вид", "ДополнительнаяОбработка");
	ПараметрыРегистрации.Вставить("Наименование", "Консоль запросов 9000");
	ПараметрыРегистрации.Вставить("Версия", DataProcessorVersion + "." + BuildVersion);
	ПараметрыРегистрации.Вставить("БезопасныйРежим", Ложь);
	ПараметрыРегистрации.Вставить("Информация", "Консоль запросов 9000");

	ТаблицаКоманд = ПолучитьТаблицуКоманд();

	ДобавитьКоманду(ТаблицаКоманд, "Консоль запросов 9000", "КонсольЗапросов9000", "ОткрытиеФормы", Истина);

	ПараметрыРегистрации.Вставить("Команды", ТаблицаКоманд);

	Возврат ПараметрыРегистрации;

EndFunction

Function ПолучитьТаблицуКоманд()

	Команды = Новый ТаблицаЗначений;
	Команды.Колонки.Добавить("Представление", Новый ОписаниеТипов("Строка"));
	Команды.Колонки.Добавить("Идентификатор", Новый ОписаниеТипов("Строка"));
	Команды.Колонки.Добавить("Использование", Новый ОписаниеТипов("Строка"));
	Команды.Колонки.Добавить("ПоказыватьОповещение", Новый ОписаниеТипов("Булево"));
	Команды.Колонки.Добавить("Модификатор", Новый ОписаниеТипов("Строка"));

	Возврат Команды;

EndFunction

Procedure ДобавитьКоманду(ТаблицаКоманд, Представление, Идентификатор, Использование, ПоказыватьОповещение = Ложь,
	Модификатор = "")
	НоваяКоманда = ТаблицаКоманд.Добавить();
	НоваяКоманда.Представление = Представление;
	НоваяКоманда.Идентификатор = Идентификатор;
	НоваяКоманда.Использование = Использование;
	НоваяКоманда.ПоказыватьОповещение = ПоказыватьОповещение;
	НоваяКоманда.Модификатор = Модификатор;
EndProcedure

#EndRegion

#Region УИ

Function ОбработкаВходитВСоставУниверсальныхИнструментов() Экспорт
	Возврат Метаданные().Имя = "УИ_КонсольЗапросов";
EndFunction

#EndRegion