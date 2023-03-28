import 'dart:ffi';
import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:api/model/user.dart';
import 'package:api/utils/app_response.dart';
import 'package:api/utils/app_utils.dart';
import 'package:api/model/note.dart';

class AppNoteController extends ResourceController {
  AppNoteController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get("number")
  Future<Response> getNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number,
      {@Bind.query("recovery") bool? recovery}) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);

      final deletedNoteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.deleted).equalTo(true);

      final deletedNote = await deletedNoteQuery.fetchOne();

      String message = "Успешное получение заметки";

  
      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.deleted).equalTo(false);
      final note = await noteQuery.fetchOne();
      if (note == null) {
        return AppResponse.ok(message: "Заметка не найдена");
      }
      note.removePropertiesFromBackingMap(["user", "id", "deleted"]);
      return AppResponse.ok(body: note.backing.contents, message: message);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения заметки');
    }
  }

  @Operation.put("number")
  Future<Response> updateNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number,
      @Bind.body() Note note) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.deleted).equalTo(false);
      final noteDB = await noteQuery.fetchOne();
      if (noteDB == null) {
        return AppResponse.ok(message: "Заметка не найдена");
      }
      final qUpdateNote = Query<Note>(managedContext)
        ..where((note) => note.id).equalTo(noteDB.id)
        ..values.category = note.category
        ..values.name = note.name
        ..values.text = note.text
        ..values.dateTimeEdit = DateTime.now().toString();
      await qUpdateNote.update();
      return AppResponse.ok(
          body: note.backing.contents, message: "Успешное обновление заметки");
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения заметки');
    }
  }

  @Operation.get()
  Future<Response> getNotes(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      {@Bind.query("search") String? search,
      @Bind.query("page") int? page,
     }) async {
    try {
      final id = AppUtils.getIdFromHeader(header);

      Query<Note>? notesQuery;

      if (search != null && search != "") {
        notesQuery = Query<Note>(managedContext)
          ..where((note) => note.name).contains(search)
          ..where((note) => note.user!.id).equalTo(id);
      } else {
        notesQuery = Query<Note>(managedContext)
          ..where((note) => note.user!.id).equalTo(id);
      }

      final notes = await notesQuery.fetch();

      List notesJson = List.empty(growable: true);

      if (page != null && page > 0) {
        int exp = (page - 1) * 20;
        for (int i = exp > 0 ? exp - 1 : exp; i < notes.length; i++) {
          final note = notes[i];
          note.removePropertiesFromBackingMap(["user", "id", "deleted"]);
          notesJson.add(note.backing.contents);
        }
      } else {
        for (final note in notes) {
          note.removePropertiesFromBackingMap(["user", "id", "deleted"]);
          notesJson.add(note.backing.contents);
        }
      }

      if (notesJson.isEmpty) {
        return AppResponse.ok(message: "Заметки не найдены");
      }

      return AppResponse.ok(
          message: 'Успешное получение заметок', body: notesJson);
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения заметок');
    }
  }


  @Operation.delete("number")
  Future<Response> deleteNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.path("number") int number) async {
    try {
      final currentUserId = AppUtils.getIdFromHeader(header);
      final noteQuery = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..where((note) => note.user!.id).equalTo(currentUserId)
        ..where((note) => note.deleted).equalTo(false);
      final note = await noteQuery.fetchOne();
      if (note == null) {
        return AppResponse.ok(message: "Заметка не найдена");
      }
      final qLogicDeleteNote = Query<Note>(managedContext)
        ..where((note) => note.number).equalTo(number)
        ..values.deleted = true;
      await qLogicDeleteNote.update();
      return AppResponse.ok(message: 'Успешное удаление заметки');
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка удаления заметки');
    }
  }

  @Operation.post()
  Future<Response> createNote(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() Note note) async {
    try {
      late final int noteId;

      final id = AppUtils.getIdFromHeader(header);

      final notesQuery = Query<Note>(managedContext)
        ..where((note) => note.user!.id).equalTo(id);

      final notes = await notesQuery.fetch();

      final noteNumber = notes.length;

      final fUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id);

      final user = await fUser.fetchOne();

      await managedContext.transaction((transaction) async {
        final qCreateNote = Query<Note>(transaction)
          ..values.number = noteNumber + 1
          ..values.name = note.name
          ..values.text = note.text
          ..values.category = note.category
          ..values.dateTimeCreate = DateTime.now().toString()
          ..values.dateTimeEdit = DateTime.now().toString()
          ..values.user = user
          ..values.deleted = false;

        final createdNote = await qCreateNote.insert();

        noteId = createdNote.id!;
      });

      final noteData = await managedContext.fetchObjectWithID<Note>(noteId);

      noteData!.removePropertiesFromBackingMap(["user", "id", "deleted"]);
      return AppResponse.ok(
        body: noteData.backing.contents,
        message: 'Успешное создание заметки',
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка создания заметки');
    }
  }
}
