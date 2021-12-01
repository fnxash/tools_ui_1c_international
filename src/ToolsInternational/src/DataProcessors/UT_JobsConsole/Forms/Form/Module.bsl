#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	UT_Common.ToolFormOnCreateAtServer(ThisObject, Cancel, StandardProcessing, Items.ScheduledJobsList.CommandBar);
EndProcedure

&AtServer
Procedure FilterOnOpen()

	ThisForm.UseBackgroundJobsFilter = True;
	// protective filter for intensive background startup
	FilterInterval = 3600;
	ThisForm.BackgroundJobsFilter = New ValueStorage(New Structure("Start", CurrentSessionDate() - FilterInterval));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateOnCreate();
	
	If BackgroundJobsListAutoUpdate = True Then
		AttachIdleHandler("BackgroundJobsAutoUpdateHandler", BackgroundListAutoUpdatePeriod);	
	EndIf;
	
	If ScheduledJobsListAutoUpdate = True Then
		AttachIdleHandler("ScheduledJobsAutoUpdateHandler", ScheduledListAutoUpdatePeriod);	
	EndIf;
		
	#If ThickClientOrdinaryApplication Then
		Items.ScheduledJobsListEventLog1.Visible = False;
	#EndIf
	#If ThickClientOrdinaryApplication OR ThickClientManagedApplication Then
		Items.ScheduledJobsListExecuteManually.Title = "At client (thick client)";
	#EndIf
	Items.BackgroundJobsListSettings.Check = BackgroundJobsListAutoUpdate;
	Items.ScheduledJobsListSettings.Check = ScheduledJobsListAutoUpdate;

EndProcedure

&AtServer
Procedure UpdateOnCreate()
	
	Try
		FilterOnOpen();
		
		BackgroundJobsListRefresh();
		ScheduledJobsListRefresh();
	Except	
		NotifyUser(ErrorInfo());
	EndTry;
	
	DataProcessorVersion = FormAttributeToValue("Object").DataProcessorVersion();
	ThisForm.Title = StrTemplate("Scheduled and background jobs v%1", DataProcessorVersion);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	DetachIdleHandler("BackgroundJobsAutoUpdateHandler");
	DetachIdleHandler("ScheduledJobsAutoUpdateHandler");
EndProcedure

&AtClient
Procedure BackgroundJobsAutoUpdateHandler()
	BackgroundJobsListRefresh();
EndProcedure

&AtClient
Procedure ScheduledJobsAutoUpdateHandler()
	ScheduledJobsListRefresh();
EndProcedure

#EndRegion

#Region ScheduledJobsListEventHandlers

&AtClient
Procedure ScheduledJobsListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	Cancel = True;
	ParametersStructure = New Structure;
	ParametersStructure.Insert("JobID", "");
	
	OnCloseNotifyHandler = New NotifyDescription("ScheduledJobsListRowAddOnClose", ThisForm);
	
	OpenForm(GetFullFormName("ScheduledJobDialog"), ParametersStructure, ThisForm, , , , OnCloseNotifyHandler, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure ScheduledJobsListRowAddOnClose(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	ScheduledJobsListRefresh();
		
	ScheduledJobID = New UUID(Result);
	Rows = ScheduledJobsList.FindRows(New Structure("ID", ScheduledJobID));
	If Rows.Count() > 0 Then
		Items.ScheduledJobsList.CurrentRow = Rows[0].GetID();		
	EndIf;
		
EndProcedure

&AtClient
Procedure ScheduledJobsListBeforeRowChange(Item, Cancel)
	Cancel = True;
	SelectedRows = Items.ScheduledJobsList.SelectedRows;
	If SelectedRows.Count() > 0 Then
		
		Row = ScheduledJobsList.FindByID(SelectedRows.Get(0));
		
		ParametersStructure = New Structure;
		ID = Row.ID;
		ParametersStructure.Insert("JobID", ID);
	
		OnCloseNotifyHandler = New NotifyDescription("ScheduledJobsListRowChangeOnClose", ThisForm);
		
		OpenForm(GetFullFormName("ScheduledJobDialog"), ParametersStructure, ThisForm, , , , OnCloseNotifyHandler, FormWindowOpeningMode.LockOwnerWindow);

	EndIf;
EndProcedure

&AtClient
Procedure ScheduledJobsListRowChangeOnClose(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		ScheduledJobsListRefresh();
	EndIf;
EndProcedure

&AtClient
Procedure ScheduledJobsListBeforeDelete(Item, Cancel)
	Try
		Cancel = Истина;
		DeleteScheduledJob();
		
		ScheduledJobsListRefresh();
	Except
		NotifyUser(ErrorInfo());
	EndTry;
EndProcedure

&AtServer
Procedure DeleteScheduledJob()
	SelectedRows = Items.ScheduledJobsList.SelectedRows;
	For Each Row In SelectedRows Do
		ScheduledJobRow = ScheduledJobsList.FindByID(Row);
		
		ScheduledJob = ScheduledJobs.FindByUUID(ScheduledJobRow.ID);
		If ScheduledJob.Predefined Then
			Raise("Unable to delete predefined job: " + ScheduledJob.Name);
		EndIf;
	EndDo;
	
	For Each Row In SelectedRows Do
		ScheduledJobRow = ScheduledJobsList.FindByID(Row);
		ScheduledJob = ScheduledJobs.FindByUUID(ScheduledJobRow.ID);
		ScheduledJob.Delete();
	EndDo;
EndProcedure

&AtClient
Procedure ScheduledJobsListOnActivateRow(Item)
	AttachIdleHandler("UpdateCurrentScheduledJobStatus", 1, True);
EndProcedure

&AtClient
Procedure UpdateCurrentScheduledJobStatus()
	CurrentRow = Items.ScheduledJobsList.CurrentRow;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
		
	CurrentData = ThisForm.ScheduledJobsList.FindByID(CurrentRow);
	If CurrentData <> Undefined Then
		LastExecutedJobAttributes = GetLastExecutedJobAttributes(CurrentData.ID);
		CurrentData.Status = LastExecutedJobAttributes.Status;
		CurrentData.Executed = LastExecutedJobAttributes.Executed;
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient 
Function GetFullFormName(FormName) 
	NameLength = 5;
	Return Left(ThisForm.FormName, StrFind(ThisForm.FormName, ".Form.") + NameLength) + FormName; 
EndFunction

&AtServerNoContext
Function GetLastExecutedJobAttributes(ИдентификаторРегламентногоЗадания, Регламентное_ = Неопределено)
	Результат = Новый Структура("Выполнялось, Состояние");
	Если Регламентное_ = Неопределено Тогда
		Регламентное = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(ИдентификаторРегламентногоЗадания);
	Иначе
		Регламентное = Регламентное_;
	КонецЕсли;
	Если Регламентное <> Неопределено Тогда
		Попытка
			// вызывает тормоза, если регламентное выполнялось давно и фоновых было много
			ПоследнееЗадание = Регламентное.ПоследнееЗадание;
		Исключение
			ПоследнееЗадание = Неопределено;
			ТекстОшибки = ОписаниеОшибки();
			NotifyUser(ТекстОшибки);
			Возврат Результат;
		КонецПопытки;
		
		Если ПоследнееЗадание <> Неопределено Тогда
			Результат.Выполнялось = Строка(ПоследнееЗадание.Начало);
			Результат.Состояние = Строка(ПоследнееЗадание.Состояние);
		КонецЕсли;

	КонецЕсли;
	Возврат Результат;
EndFunction

&НаКлиентеНаСервереБезКонтекста
Процедура NotifyUser(ТекстСообщения)
	Сообщение = Новый СообщениеПользователю();
	Сообщение.Текст = ТекстСообщения;
	Сообщение.Сообщить();
КонецПроцедуры

#EndRegion

#Область ОбработчикиКомандТаблицыСписокРегламентныхЗаданий

&НаКлиенте
Процедура УстановитьОтборРегламентныхЗаданий(Команда)
	СтруктураПараметров = Новый Структура;
	СтруктураПараметров.Вставить("Отбор", ОтборРегламентныхЗаданий);
	
	ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("УстановитьОтборРегламентныхЗаданийЗавершение", ЭтаФорма);
	
	ОткрытьФорму(GetFullFormName("ДиалогОтбораРегламентногоЗадания"), СтруктураПараметров, ЭтаФорма, , , , ОписаниеОповещенияОЗакрытии, РежимОткрытияОкнаФормы.БлокироватьОкноВладельца);
КонецПроцедуры

&НаКлиенте
Процедура УстановитьОтборРегламентныхЗаданийЗавершение(РезультатЗакрытия, ДополнительныеПараметры) Экспорт
	Если ТипЗнч(РезультатЗакрытия) = Тип("Структура") Тогда
		ОтборРегламентныхЗаданий = РезультатЗакрытия;
		ОтборРегламентныхЗаданийВключен = Истина;
		ScheduledJobsListRefresh();
	КонецЕсли;
КонецПроцедуры

&НаКлиенте
Процедура ОтключитьОтборРегламентныхЗаданий(Команда)
	ОтборРегламентныхЗаданийВключен = Ложь;
	ScheduledJobsListRefresh();
КонецПроцедуры

&НаКлиенте
Процедура ОбновитьРегламентныеЗадания(Команда)
	ScheduledJobsListRefresh(Истина);
КонецПроцедуры

&НаСервере
Процедура ScheduledJobsListRefresh(ПолучитьСостояниеВсех = Ложь)
	Перем ТекущийИдентификатор;

	ТекущаяСтрока = Элементы.СписокРегламентныхЗаданий.ТекущаяСтрока;
	Если ТекущаяСтрока <> Неопределено Тогда
		ТекСтрока = ScheduledJobsList.НайтиПоИдентификатору(ТекущаяСтрока);
		ТекущийИдентификатор = ТекСтрока.ID;
	КонецЕсли;

	Идентификаторы = Новый Массив;
	
	ВыделенныеСтроки = Элементы.СписокРегламентныхЗаданий.ВыделенныеСтроки;
	Для Каждого ВыделеннаяСтрока Из ВыделенныеСтроки Цикл
		ТекСтрока = ScheduledJobsList.НайтиПоИдентификатору(ВыделеннаяСтрока);
		Идентификаторы.Добавить(ТекСтрока.ID);
	КонецЦикла;
	
	ScheduledJobsList.Очистить();
	
	ВывестиРегламентные(ПолучитьСостояниеВсех);
	
	ScheduledJobsList.Сортировать("Метаданные");
	
	Если ТекущийИдентификатор <> Неопределено Тогда
		Строки = ScheduledJobsList.НайтиСтроки(Новый Структура("Идентификатор", ТекущийИдентификатор));
		Если Строки.Количество() > 0 Тогда
			Элементы.СписокРегламентныхЗаданий.ТекущаяСтрока = Строки[0].ПолучитьИдентификатор();
		КонецЕсли;
	КонецЕсли;

	Если Идентификаторы.Количество() > 0 Тогда
		ВыделенныеСтроки.Очистить();
	КонецЕсли;
	
	Для Каждого Идентификатор Из Идентификаторы Цикл
		Строки = ScheduledJobsList.НайтиСтроки(Новый Структура("Идентификатор", Идентификатор));
		Если Строки.Количество() > 0 Тогда
			ВыделенныеСтроки.Добавить(Строки[0].ПолучитьИдентификатор());
		КонецЕсли;
	КонецЦикла;
	
КонецПроцедуры

&НаСервере
Функция ПолучитьОтборРегламентных()
	Отбор = Неопределено;
	СтрокаОтбора = "";
	Если ОтборРегламентныхЗаданийВключен = Истина Тогда
		Отбор = ОтборРегламентныхЗаданий;
		Для Каждого Элемент Из Отбор Цикл
			Если СтрокаОтбора <> "" Тогда
				 СтрокаОтбора = СтрокаОтбора + ";";
			КонецЕсли;
			СтрокаОтбора = СтрокаОтбора + Элемент.Ключ + ": " + Элемент.Значение;
		КонецЦикла;
		Если СтрокаОтбора <> "" Тогда
			СтрокаОтбора = " (" + СтрокаОтбора + ")";
		КонецЕсли;
	КонецЕсли;
	Элементы.РегламентныеЗадания.Заголовок = "Регламентные задания" + СтрокаОтбора;
	Возврат Отбор;
КонецФункции
	
&НаСервере
Процедура ВывестиРегламентные(ПолучитьСостояниеВсех = Ложь)
	
	Отбор = ПолучитьОтборРегламентных();
	Попытка
		Регламентные = РегламентныеЗадания.ПолучитьРегламентныеЗадания(Отбор);
	Исключение
		ТекстОшибки = ОписаниеОшибки();
		NotifyUser(ТекстОшибки);
		Возврат;
	КонецПопытки;
	
	Таймаут = Ложь;
	НачалоЗамера = ТекущаяУниверсальнаяДатаВМиллисекундах();
	Сч = 0;
	Количество = Регламентные.Количество();
	Для Каждого Регламентное Из Регламентные Цикл
		НоваяСтрока = ScheduledJobsList.Добавить();
		НоваяСтрока.Metadata = Регламентное.Метаданные.Представление();
		НоваяСтрока.Name = Регламентное.Наименование;
		НоваяСтрока.Key = Регламентное.Ключ;
		НоваяСтрока.Schedule = Регламентное.Расписание;
		НоваяСтрока.User = Регламентное.ИмяПользователя;
		НоваяСтрока.Predefined = Регламентное.Предопределенное;
		НоваяСтрока.Use = Регламентное.Использование;
		НоваяСтрока.ID = Регламентное.УникальныйИдентификатор;
		НоваяСтрока.Method = Регламентное.Метаданные.ИмяМетода;
		
		ТаймаутВыводаМиллисекунд = 200;
		ДлительностьВывода = ТекущаяУниверсальнаяДатаВМиллисекундах() - НачалоЗамера;
		Если НЕ Таймаут И ДлительностьВывода < ТаймаутВыводаМиллисекунд ИЛИ ПолучитьСостояниеВсех Тогда
			Сч = Сч + 1;
			// На больших базах подвисает...
			СвойстваПоследнегоВыполненного = GetLastExecutedJobAttributes(НоваяСтрока.ID, Регламентное);
			НоваяСтрока.Status = СвойстваПоследнегоВыполненного.Состояние;
			НоваяСтрока.Executed = СвойстваПоследнегоВыполненного.Выполнялось;
		КонецЕсли;
		Если НЕ Таймаут И ДлительностьВывода > ТаймаутВыводаМиллисекунд Тогда
			Таймаут = Истина;
		КонецЕсли; 
		
		ИмяРегламентногоЗадания = НоваяСтрока.Metadata + ?(ЗначениеЗаполнено(НоваяСтрока.Name), ":" + НоваяСтрока.Name, "");
		Строки = СписокФоновыхЗаданий.НайтиСтроки(Новый Структура("Метод, Наименование", НоваяСтрока.Method, НоваяСтрока.Name));
		Для Каждого Фоновое Из Строки Цикл
			Фоновое.Регламентное = ИмяРегламентногоЗадания;
		КонецЦикла;
	КонецЦикла;	
	
	ВремяЗаполненияРегламентных = ТекущаяУниверсальнаяДатаВМиллисекундах() - НачалоЗамера;
	
	ОптимизацияТекстПояснения = СтрШаблон("За %1 мсек. получено состояние %2 из %3 регламентных заданий,"
		+ " но обновление происходит и при активации строки.", ВремяЗаполненияРегламентных, Сч, Количество)
		+ " Для отображения состояния сразу всех воспользуйтесь командой обновления списка регламентных заданий.";
		
	Элементы.ScheduledJobsListExecuted.Подсказка = ОптимизацияТекстПояснения;
	Элементы.ScheduledJobsListExecuted.Заголовок = "Выполнялось" + ?(Сч = Количество, "", "*");
	Элементы.ScheduledJobsListStatus.Подсказка = ОптимизацияТекстПояснения;
	Элементы.ScheduledJobsListStatus.Заголовок = "Состояние" + ?(Сч = Количество, "", "*");
	
КонецПроцедуры

&НаКлиенте
Процедура Расписание(Команда)
	ВыделенныеСтроки = Элементы.СписокРегламентныхЗаданий.ВыделенныеСтроки;
	Если ВыделенныеСтроки.Количество() > 0 Тогда
		
		Строка = ScheduledJobsList.НайтиПоИдентификатору(ВыделенныеСтроки.Получить(0));
		Расписание = ПолучитьРасписаниеРегламентногоЗадания(Строка.ID);
		Диалог = Новый ДиалогРасписанияРегламентногоЗадания(Расписание);
		ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("ДиалогРасписанияРегламентногоЗаданияОткрытьЗавершение", ЭтаФорма);
		
		Диалог.Показать(ОписаниеОповещенияОЗакрытии);

	КонецЕсли;
КонецПроцедуры

&НаСервере
Функция ПолучитьРасписаниеРегламентногоЗадания(УникальныйНомерЗадания)
	ОбъектЗадания = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(УникальныйНомерЗадания);
	Если ОбъектЗадания = Неопределено Тогда
		Возврат Новый РасписаниеРегламентногоЗадания;
	КонецЕсли;
	
	Возврат ОбъектЗадания.Расписание;
КонецФункции

&НаКлиенте
Процедура ДиалогРасписанияРегламентногоЗаданияОткрытьЗавершение(Расписание, ДополнительныеПараметры) Экспорт
	Если Расписание <> Неопределено Тогда
		ВыделенныеСтроки = Элементы.СписокРегламентныхЗаданий.ВыделенныеСтроки;
		Если ВыделенныеСтроки.Количество() > 0 Тогда
			Строка = ScheduledJobsList.НайтиПоИдентификатору(ВыделенныеСтроки.Получить(0));
			УстановитьРасписаниеРегламентногоЗадания(Строка.ID, Строка.Name, Расписание, Строка.Metadata);
			Строка.Schedule = Расписание;
		КонецЕсли;
	КонецЕсли;
КонецПроцедуры

&НаСервере
Функция УстановитьРасписаниеРегламентногоЗадания(Идентификатор, Наименование, Расписание, ИмяЗадания)
	ОбъектЗадания = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(Идентификатор);
	Если ОбъектЗадания = Неопределено Тогда
		РедОбъектЗадания = РегламентныеЗадания.СоздатьРегламентноеЗадание(ИмяЗадания);
		РедОбъектЗадания.Наименование = Наименование;
		РедОбъектЗадания.Использование = Истина;
	Иначе
		РедОбъектЗадания = ОбъектЗадания;
	КонецЕсли;
	
	РедОбъектЗадания.Расписание = Расписание;
	Попытка
		РедОбъектЗадания.Записать();
	Исключение
		ВызватьИсключение "Произошла ошибка при сохранении расписания выполнения обменов. Возможно данные расписания были изменены. Закройте форму настройки и повторите попытку изменения расписания еще раз.
		|Подробное описание ошибки: " + ОписаниеОшибки();
	КонецПопытки;
	
	Возврат Истина;
КонецФункции

&НаКлиенте
Процедура НастройкаСпискаРегламентныхЗаданий(Команда)
	СтруктураПараметров = Новый Структура;
	СтруктураПараметров.Вставить("АвтоОбновление", ScheduledJobsListAutoUpdate);
	СтруктураПараметров.Вставить("ПериодАвтоОбновления", ScheduledListAutoUpdatePeriod);
	
	ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("НастройкаСпискаРегламентныхЗаданийЗавершение", ЭтаФорма);
	
	ОткрытьФорму(GetFullFormName("ДиалогНастроекСписка"), СтруктураПараметров, ЭтаФорма, , , , ОписаниеОповещенияОЗакрытии, РежимОткрытияОкнаФормы.БлокироватьОкноВладельца);
КонецПроцедуры

&НаКлиенте
Процедура НастройкаСпискаРегламентныхЗаданийЗавершение(РезультатЗакрытия, ДополнительныеПараметры) Экспорт
	Если ТипЗнч(РезультатЗакрытия) = Тип("Структура") Тогда
		ScheduledJobsListAutoUpdate = РезультатЗакрытия.Автообновление;
		ScheduledListAutoUpdatePeriod = РезультатЗакрытия.ПериодАвтообновления;
		
		ОтключитьОбработчикОжидания("ScheduledJobsAutoUpdateHandler");
		Если ScheduledJobsListAutoUpdate = Истина Тогда
			ПодключитьОбработчикОжидания("ScheduledJobsAutoUpdateHandler", ScheduledListAutoUpdatePeriod);	
		КонецЕсли;
		Элементы.СписокРегламентныхЗаданийНастройкаСпискаРегламентныхЗаданий.Пометка = ScheduledJobsListAutoUpdate;
	КонецЕсли;
КонецПроцедуры

&НаКлиенте
Процедура ВыполнитьЗаданиеВручную(Команда)
	ТекущаяСтрока = Элементы.СписокРегламентныхЗаданий.ТекущиеДанные;
	Если ТекущаяСтрока <> Неопределено Тогда
		ВыполнитьЗаданиеВручнуюНаСервере(ТекущаяСтрока.Идентификатор);
	КонецЕсли;
КонецПроцедуры

&НаСервере
Процедура ВыполнитьЗаданиеВручнуюНаСервере(УникальныйИдентификатор)
	Идентификатор = Новый УникальныйИдентификатор(УникальныйИдентификатор);
	Задание = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(Идентификатор);
	
	ИмяМетода = Задание.Метаданные.ИмяМетода;
		
	// Подготовка команды для выполнения метода вместо фонового задания.
	СтрокаПараметров = "";
	Индекс = 0;
	Пока Индекс < Задание.Параметры.Количество() Цикл
		СтрокаПараметров = СтрокаПараметров + "Задание.Параметры[" + Индекс + "]";
		Если Индекс < (Задание.Параметры.Количество() - 1) Тогда
			СтрокаПараметров = СтрокаПараметров + ",";
		КонецЕсли;
		Индекс = Индекс + 1;
	КонецЦикла;
	
	Выполнить("" + ИмяМетода + "(" + СтрокаПараметров + ");");

КонецПроцедуры

&НаКлиенте
Процедура ЗапуститьЗадание(Команда)
	ТекущаяСтрока = Элементы.СписокРегламентныхЗаданий.ТекущиеДанные;
	Если ТекущаяСтрока <> Неопределено Тогда
		ЗапуститьЗаданиеНаСервере(ТекущаяСтрока.Идентификатор);
	КонецЕсли;
КонецПроцедуры

&НаСервере
Процедура ЗапуститьЗаданиеНаСервере(УникальныйИдентификатор)
	
	Идентификатор = Новый УникальныйИдентификатор(УникальныйИдентификатор);
	Задание = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(Идентификатор);
		
	// проверка на выполнение в текущий момент
	Отбор = Новый Структура;
	Отбор.Вставить("Ключ", Строка(Задание.УникальныйИдентификатор));
	Отбор.Вставить("Состояние ", СостояниеФоновогоЗадания.Активно);		
	МассивЗаданий = ФоновыеЗадания.ПолучитьФоновыеЗадания(Отбор);
	
	ИдентификаторНовогоЗадания = Неопределено;
	
	Если МассивЗаданий.Количество() = 0 Тогда 
		НаименованиеФоновогоЗадания = "Запуск вручную: " + Задание.Метаданные.Синоним;
		ФоновоеЗадание = ФоновыеЗадания.Выполнить(Задание.Метаданные.ИмяМетода, Задание.Параметры, Строка(Задание.УникальныйИдентификатор), НаименованиеФоновогоЗадания);
		ИдентификаторНовогоЗадания = ФоновоеЗадание.УникальныйИдентификатор;
	Иначе
		NotifyUser("Задание уже запущено");
	КонецЕсли;
		
	ScheduledJobsListRefresh();
	BackgroundJobsListRefresh(ИдентификаторНовогоЗадания);
КонецПроцедуры

&НаКлиенте
Процедура ЖурналРегистрации(Команда)
    ИмяФормыЖР = "ВнешняяОбработка.StandardEventLog.Форма";
    ПодключитьВнешнююОбработкуНаСервере();
    ОткрытьФорму(ИмяФормыЖР);
КонецПроцедуры

&НаСервере
Процедура ПодключитьВнешнююОбработкуНаСервере()
	// BSLLS:UsingExternalCodeTools-off
	// https://github.com/1c-syntax/bsl-language-server/issues/1283
    ВнешниеОбработки.Подключить("v8res://mngbase/StandardEventLog.epf", "StandardEventLog", Истина);
	// BSLLS:UsingExternalCodeTools-on
КонецПроцедуры

//@skip-warning
&НаКлиенте
Процедура Подключаемый_ВыполнитьОбщуюКомандуИнструментов(Команда) 
	UT_CommonClient.Подключаемый_ВыполнитьОбщуюКомандуИнструментов(ЭтотОбъект, Команда);
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиСобытийЭлементовТаблицыФормыСписокФоновыхЗаданий

&НаКлиенте
Процедура СписокФоновыхЗаданийПередНачаломДобавления(Элемент, Отказ, Копирование, Родитель, Группа)
	Отказ = Истина;
	
	СтруктураПараметров = Новый Структура;
	СтруктураПараметров.Вставить("ИдентификаторЗадания", "");
	Если Копирование Тогда
		ТекущиеДанные = Элементы.СписокФоновыхЗаданий.ТекущиеДанные;
		Если ТекущиеДанные <> Неопределено Тогда
			СтруктураПараметров.Вставить("ИмяМетода", ТекущиеДанные.Метод);
			СтруктураПараметров.Вставить("Наименование", ТекущиеДанные.Наименование);
			СтруктураПараметров.Вставить("Ключ", ТекущиеДанные.Ключ);
		КонецЕсли;
	КонецЕсли;

	ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("СписокФоновыхЗаданийПередНачаломДобавленияЗавершение", ЭтаФорма);
	
	ОткрытьФорму(GetFullFormName("ДиалогФоновогоЗадания"), СтруктураПараметров, ЭтаФорма, , , , ОписаниеОповещенияОЗакрытии, РежимОткрытияОкнаФормы.БлокироватьОкноВладельца);
КонецПроцедуры

&НаКлиенте
Процедура СписокФоновыхЗаданийПередНачаломДобавленияЗавершение(РезультатЗакрытия, ДополнительныеПараметры) Экспорт
	Если РезультатЗакрытия <> Неопределено Тогда
	    BackgroundJobsListRefresh();			
	КонецЕсли;
КонецПроцедуры

&НаКлиенте
Процедура СписокФоновыхЗаданийПередНачаломИзменения(Элемент, Отказ)
	Отказ = Истина;
КонецПроцедуры

&НаКлиенте
Процедура СписокФоновыхЗаданийПередУдалением(Элемент, Отказ)
	Отказ = Истина;
КонецПроцедуры

&НаКлиенте
Процедура СписокФоновыхЗаданийВыбор(Элемент, ВыбраннаяСтрока, Поле, СтандартнаяОбработка)
	Если Поле.Имя = "СписокФоновыхЗаданийСообщения" Тогда
		СписокФоновыхЗаданийСообщенияВыборНаСервере(ВыбраннаяСтрока);
	КонецЕсли;
КонецПроцедуры

&НаСервере
Процедура СписокФоновыхЗаданийСообщенияВыборНаСервере(ИдентификаторСтроки)
	ТекущаяСтрока = СписокФоновыхЗаданий.НайтиПоИдентификатору(ИдентификаторСтроки);
	Фоновое = ФоновыеЗадания.НайтиПоУникальномуИдентификатору(ТекущаяСтрока.Идентификатор);
	Если Фоновое <> Неопределено Тогда
		СообщенияПользователю = Фоновое.ПолучитьСообщенияПользователю();
		Для Каждого Сообщение Из СообщенияПользователю Цикл
			NotifyUser(Сообщение.Текст);
		КонецЦикла;
	КонецЕсли;
КонецПроцедуры

#КонецОбласти

#Область ОбработчикиКомандТаблицыСписокФоновыхЗаданий

&НаКлиенте
Процедура ОтменитьФоновоеЗадание(Команда)
	Попытка
		ОтменитьФоновыеЗадания();
		BackgroundJobsListRefresh();
	Исключение	
		ТекстОшибки = ОписаниеОшибки();
		NotifyUser(ТекстОшибки);
	КонецПопытки;
КонецПроцедуры

&НаСервере
Процедура ОтменитьФоновыеЗадания()
	ВыделенныеСтроки = Элементы.СписокФоновыхЗаданий.ВыделенныеСтроки;
	Для Каждого Стр Из ВыделенныеСтроки Цикл
		Строка = СписокФоновыхЗаданий.НайтиПоИдентификатору(Стр);
		ТекИдентификатор = Новый УникальныйИдентификатор(Строка.Идентификатор);
		ФоновоеЗадание = ФоновыеЗадания.НайтиПоУникальномуИдентификатору(ТекИдентификатор);
		ФоновоеЗадание.Отменить();
	КонецЦикла;
КонецПроцедуры

&НаКлиенте
Процедура УстановитьОтборФоновыхЗаданий(Команда)
	СтруктураПараметров = Новый Структура;
	СтруктураПараметров.Вставить("Отбор", BackgroundJobsFilter);
	
	ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("УстановитьBackgroundJobsFilterЗавершение", ЭтаФорма);
	
	ОткрытьФорму(GetFullFormName("ДиалогОтбораФоновогоЗадания"), СтруктураПараметров, ЭтаФорма, , , , ОписаниеОповещенияОЗакрытии, РежимОткрытияОкнаФормы.БлокироватьОкноВладельца);
КонецПроцедуры

&НаКлиенте
Процедура УстановитьBackgroundJobsFilterЗавершение(РезультатЗакрытия, ДополнительныеПараметры) Экспорт
	Если ТипЗнч(РезультатЗакрытия) = Тип("ХранилищеЗначения") Тогда
		BackgroundJobsFilter = РезультатЗакрытия;
		UseBackgroundJobsFilter = Истина;
		BackgroundJobsListRefresh();
	КонецЕсли;
КонецПроцедуры

&НаКлиенте
Процедура ОтборПоТекущему(Команда)
	ТекИдентификаторСтроки = Элементы.СписокРегламентныхЗаданий.ТекущаяСтрока;
	Если ТекИдентификаторСтроки <> Неопределено Тогда
		ОтборПоТекущемуНаСервере(ТекИдентификаторСтроки);
	КонецЕсли;
КонецПроцедуры

&НаСервере
Процедура ОтборПоТекущемуНаСервере(ТекИдентификаторСтроки)
	ТекЗадание = ScheduledJobsList.НайтиПоИдентификатору(ТекИдентификаторСтроки);
	
	ТекОтбор = Новый Структура;
	
	Регламентное = РегламентныеЗадания.НайтиПоУникальномуИдентификатору(ТекЗадание.ID);
	ТекОтбор.Вставить("РегламентноеЗадание", Регламентное);

	BackgroundJobsFilter = Новый ХранилищеЗначения(ТекОтбор);
	UseBackgroundJobsFilter = Истина;
	BackgroundJobsListRefresh();

КонецПроцедуры

&НаКлиенте
Процедура ОтключитьОтборФоновыхЗаданий(Команда)
	FilterOnOpen();
	BackgroundJobsListRefresh();
КонецПроцедуры

&НаКлиенте
Процедура ОбновитьФоновыеЗадания(Команда)
	BackgroundJobsListRefresh();
КонецПроцедуры

&НаСервере
Процедура BackgroundJobsListRefresh(ИдентификаторНовогоЗадания = Неопределено)
	Перем ТекущийИдентификатор;

	ТекущаяСтрока = Элементы.СписокФоновыхЗаданий.ТекущаяСтрока;
	Если ТекущаяСтрока <> Неопределено Тогда
		ТекСтрока = СписокФоновыхЗаданий.НайтиПоИдентификатору(ТекущаяСтрока);
		ТекущийИдентификатор = ТекСтрока.Идентификатор;
	КонецЕсли;
	
	Если ЗначениеЗаполнено(ИдентификаторНовогоЗадания) Тогда
		ТекущийИдентификатор = ИдентификаторНовогоЗадания;
	КонецЕсли;
	
	Идентификаторы = Новый Массив;
	
	ВыделенныеСтроки = Элементы.СписокФоновыхЗаданий.ВыделенныеСтроки;
	Для Каждого ВыделеннаяСтрока Из ВыделенныеСтроки Цикл
		ТекСтрока = СписокФоновыхЗаданий.НайтиПоИдентификатору(ВыделеннаяСтрока);
		Идентификаторы.Добавить(ТекСтрока.Идентификатор);
	КонецЦикла;

	СписокФоновыхЗаданий.Очистить();
	
	ВывестиФоновые();
	
	Если ТекущийИдентификатор <> Неопределено Тогда
		Строки = СписокФоновыхЗаданий.НайтиСтроки(Новый Структура("Идентификатор", ТекущийИдентификатор));
		Если Строки.Количество() > 0 Тогда
			Элементы.СписокФоновыхЗаданий.ТекущаяСтрока = Строки[0].ПолучитьИдентификатор();
		КонецЕсли;
	КонецЕсли;

	Если Идентификаторы.Количество() > 0 Тогда
		ВыделенныеСтроки.Очистить();
	КонецЕсли;
	
	Для Каждого Идентификатор Из Идентификаторы Цикл
		Строки = СписокФоновыхЗаданий.НайтиСтроки(Новый Структура("Идентификатор", Идентификатор));
		Если Строки.Количество() > 0 Тогда
			ВыделенныеСтроки.Добавить(Строки[0].ПолучитьИдентификатор());
		КонецЕсли;
	КонецЦикла;
	
КонецПроцедуры

&НаСервере
Процедура ВывестиФоновые()
	
	Отбор = ПолучитьОтборФоновых();
	
	Попытка
		Фоновые = ФоновыеЗадания.ПолучитьФоновыеЗадания(Отбор);
	Исключение
		ТекстОшибки = ОписаниеОшибки();
		NotifyUser(ТекстОшибки);
		Возврат;
	КонецПопытки;
	
	Для Каждого Фоновое Из Фоновые Цикл
		НоваяСтрока = СписокФоновыхЗаданий.Добавить();
		
		НоваяСтрока.Сообщения = Фоновое.ПолучитьСообщенияПользователю().Количество();
		Строки = ScheduledJobsList.НайтиСтроки(Новый Структура("Метод, Наименование", Фоновое.ИмяМетода, Фоновое.Наименование));
		Если Строки.Количество() > 0 Тогда
			Если СписокФоновыхЗаданий.Индекс(НоваяСтрока) = 0 Тогда
				Строки[0].Выполнялось = Фоновое.Начало;
				Строки[0].Состояние = Фоновое.Состояние;
			КонецЕсли;
			ИмяРегламентногоЗадания = Строки[0].Метаданные + ":" + Строки[0].Наименование;
			НоваяСтрока.Регламентное = ИмяРегламентногоЗадания;
		Иначе
			НоваяСтрока.Регламентное = Фоновое.УникальныйИдентификатор;
		КонецЕсли;
			
		НоваяСтрока.Наименование = Фоновое.Наименование;
		НоваяСтрока.Ключ = Фоновое.Ключ;
		НоваяСтрока.Метод = Фоновое.ИмяМетода;
		НоваяСтрока.Состояние = Фоновое.Состояние;
		НоваяСтрока.Начало = Фоновое.Начало;
		НоваяСтрока.Конец = Фоновое.Конец;
		НоваяСтрока.Сервер = Фоновое.Расположение;
		
		Если Фоновое.ИнформацияОбОшибке <> Неопределено Тогда
			НоваяСтрока.Ошибки = Фоновое.ИнформацияОбОшибке.Описание;
		КонецЕсли;
		
		НоваяСтрока.Идентификатор = Фоновое.УникальныйИдентификатор;
		НоваяСтрока.СостояниеЗадания = Фоновое.Состояние;
	КонецЦикла;
		
КонецПроцедуры

&НаСервере
Функция ПолучитьОтборФоновых()
	Отбор = Неопределено;
	СтрокаОтбора = "";
	Если UseBackgroundJobsFilter = Истина Тогда
		Отбор = BackgroundJobsFilter.Получить();
		Для Каждого Элемент Из Отбор Цикл
			Если СтрокаОтбора <> "" Тогда
				 СтрокаОтбора = СтрокаОтбора + ";";
			КонецЕсли;
			СтрокаОтбора = СтрокаОтбора + Элемент.Ключ + ": " + Элемент.Значение;
		КонецЦикла;
		Если СтрокаОтбора <> "" Тогда
			СтрокаОтбора = " (" + СтрокаОтбора + ")";
		КонецЕсли;
	КонецЕсли;
	Элементы.ФоновыеЗадания.Заголовок = "Фоновые задания" + СтрокаОтбора;
	Возврат Отбор;
КонецФункции

&НаКлиенте
Процедура НастройкаСпискаФоновыхЗаданий(Команда)
	
	СтруктураПараметров = Новый Структура;
	СтруктураПараметров.Вставить("АвтоОбновление", BackgroundJobsListAutoUpdate);
	СтруктураПараметров.Вставить("ПериодАвтоОбновления", BackgroundListAutoUpdatePeriod);
	
	ОписаниеОповещенияОЗакрытии = Новый ОписаниеОповещения("НастройкаСпискаФоновыхЗаданийЗавершение", ЭтаФорма);
	
	ОткрытьФорму(GetFullFormName("ДиалогНастроекСписка"), СтруктураПараметров, ЭтаФорма, , , , ОписаниеОповещенияОЗакрытии, РежимОткрытияОкнаФормы.БлокироватьОкноВладельца);
КонецПроцедуры

&НаКлиенте
Процедура НастройкаСпискаФоновыхЗаданийЗавершение(РезультатЗакрытия, ДополнительныеПараметры) Экспорт
	Если ТипЗнч(РезультатЗакрытия) = Тип("Структура") Тогда
		BackgroundJobsListAutoUpdate = РезультатЗакрытия.Автообновление;
		BackgroundListAutoUpdatePeriod = РезультатЗакрытия.ПериодАвтоОбновления;
		
		ОтключитьОбработчикОжидания("BackgroundJobsAutoUpdateHandler");
		Если BackgroundJobsListAutoUpdate = Истина Тогда
			ПодключитьОбработчикОжидания("BackgroundJobsAutoUpdateHandler", BackgroundListAutoUpdatePeriod);	
		КонецЕсли;
		
		Элементы.BackgroundJobsListSettings.Пометка = BackgroundJobsListAutoUpdate;
	КонецЕсли;
КонецПроцедуры

#КонецОбласти