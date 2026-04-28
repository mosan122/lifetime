// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'milestone_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMilestoneCollectionCollection on Isar {
  IsarCollection<MilestoneCollection> get milestoneCollections =>
      this.collection();
}

const MilestoneCollectionSchema = CollectionSchema(
  name: r'MilestoneCollection',
  id: 6801414828442966016, // nearest JS-safe value (web compat)
  properties: {
    r'category': PropertySchema(
      id: 0,
      name: r'category',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'description': PropertySchema(
      id: 2,
      name: r'description',
      type: IsarType.string,
    ),
    r'driveFileId': PropertySchema(
      id: 3,
      name: r'driveFileId',
      type: IsarType.string,
    ),
    r'eventDate': PropertySchema(
      id: 4,
      name: r'eventDate',
      type: IsarType.dateTime,
    ),
    r'id': PropertySchema(
      id: 5,
      name: r'id',
      type: IsarType.string,
    ),
    r'isPublic': PropertySchema(
      id: 6,
      name: r'isPublic',
      type: IsarType.bool,
    ),
    r'latitude': PropertySchema(
      id: 7,
      name: r'latitude',
      type: IsarType.double,
    ),
    r'locationName': PropertySchema(
      id: 8,
      name: r'locationName',
      type: IsarType.string,
    ),
    r'longitude': PropertySchema(
      id: 9,
      name: r'longitude',
      type: IsarType.double,
    ),
    r'media': PropertySchema(
      id: 10,
      name: r'media',
      type: IsarType.objectList,
      target: r'MediaAssetEmbed',
    ),
    r'participants': PropertySchema(
      id: 11,
      name: r'participants',
      type: IsarType.stringList,
    ),
    r'syncStatus': PropertySchema(
      id: 12,
      name: r'syncStatus',
      type: IsarType.string,
      enumMap: _MilestoneCollectionsyncStatusEnumValueMap,
    ),
    r'title': PropertySchema(
      id: 13,
      name: r'title',
      type: IsarType.string,
    ),
    r'userId': PropertySchema(
      id: 14,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _milestoneCollectionEstimateSize,
  serialize: _milestoneCollectionSerialize,
  deserialize: _milestoneCollectionDeserialize,
  deserializeProp: _milestoneCollectionDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'id': IndexSchema(
      id: -3268401673993471488, // nearest JS-safe value (web compat)
      name: r'id',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'id',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {r'MediaAssetEmbed': MediaAssetEmbedSchema},
  getId: _milestoneCollectionGetId,
  getLinks: _milestoneCollectionGetLinks,
  attach: _milestoneCollectionAttach,
  version: '3.1.0+1',
);

int _milestoneCollectionEstimateSize(
  MilestoneCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.category.length * 3;
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.driveFileId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.locationName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.media.length * 3;
  {
    final offsets = allOffsets[MediaAssetEmbed]!;
    for (var i = 0; i < object.media.length; i++) {
      final value = object.media[i];
      bytesCount +=
          MediaAssetEmbedSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.participants.length * 3;
  {
    for (var i = 0; i < object.participants.length; i++) {
      final value = object.participants[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.syncStatus.name.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _milestoneCollectionSerialize(
  MilestoneCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.category);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.description);
  writer.writeString(offsets[3], object.driveFileId);
  writer.writeDateTime(offsets[4], object.eventDate);
  writer.writeString(offsets[5], object.id);
  writer.writeBool(offsets[6], object.isPublic);
  writer.writeDouble(offsets[7], object.latitude);
  writer.writeString(offsets[8], object.locationName);
  writer.writeDouble(offsets[9], object.longitude);
  writer.writeObjectList<MediaAssetEmbed>(
    offsets[10],
    allOffsets,
    MediaAssetEmbedSchema.serialize,
    object.media,
  );
  writer.writeStringList(offsets[11], object.participants);
  writer.writeString(offsets[12], object.syncStatus.name);
  writer.writeString(offsets[13], object.title);
  writer.writeString(offsets[14], object.userId);
}

MilestoneCollection _milestoneCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MilestoneCollection();
  object.category = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.description = reader.readStringOrNull(offsets[2]);
  object.driveFileId = reader.readStringOrNull(offsets[3]);
  object.eventDate = reader.readDateTime(offsets[4]);
  object.id = reader.readString(offsets[5]);
  object.isPublic = reader.readBool(offsets[6]);
  object.isarId = id;
  object.latitude = reader.readDoubleOrNull(offsets[7]);
  object.locationName = reader.readStringOrNull(offsets[8]);
  object.longitude = reader.readDoubleOrNull(offsets[9]);
  object.media = reader.readObjectList<MediaAssetEmbed>(
        offsets[10],
        MediaAssetEmbedSchema.deserialize,
        allOffsets,
        MediaAssetEmbed(),
      ) ??
      [];
  object.participants = reader.readStringList(offsets[11]) ?? [];
  object.syncStatus = _MilestoneCollectionsyncStatusValueEnumMap[
          reader.readStringOrNull(offsets[12])] ??
      SyncStatus.synced;
  object.title = reader.readString(offsets[13]);
  object.userId = reader.readString(offsets[14]);
  return object;
}

P _milestoneCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDoubleOrNull(offset)) as P;
    case 10:
      return (reader.readObjectList<MediaAssetEmbed>(
            offset,
            MediaAssetEmbedSchema.deserialize,
            allOffsets,
            MediaAssetEmbed(),
          ) ??
          []) as P;
    case 11:
      return (reader.readStringList(offset) ?? []) as P;
    case 12:
      return (_MilestoneCollectionsyncStatusValueEnumMap[
              reader.readStringOrNull(offset)] ??
          SyncStatus.synced) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _MilestoneCollectionsyncStatusEnumValueMap = {
  r'synced': r'synced',
  r'pending': r'pending',
};
const _MilestoneCollectionsyncStatusValueEnumMap = {
  r'synced': SyncStatus.synced,
  r'pending': SyncStatus.pending,
};

Id _milestoneCollectionGetId(MilestoneCollection object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _milestoneCollectionGetLinks(
    MilestoneCollection object) {
  return [];
}

void _milestoneCollectionAttach(
    IsarCollection<dynamic> col, Id id, MilestoneCollection object) {
  object.isarId = id;
}

extension MilestoneCollectionByIndex on IsarCollection<MilestoneCollection> {
  Future<MilestoneCollection?> getById(String id) {
    return getByIndex(r'id', [id]);
  }

  MilestoneCollection? getByIdSync(String id) {
    return getByIndexSync(r'id', [id]);
  }

  Future<bool> deleteById(String id) {
    return deleteByIndex(r'id', [id]);
  }

  bool deleteByIdSync(String id) {
    return deleteByIndexSync(r'id', [id]);
  }

  Future<List<MilestoneCollection?>> getAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndex(r'id', values);
  }

  List<MilestoneCollection?> getAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'id', values);
  }

  Future<int> deleteAllById(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'id', values);
  }

  int deleteAllByIdSync(List<String> idValues) {
    final values = idValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'id', values);
  }

  Future<Id> putById(MilestoneCollection object) {
    return putByIndex(r'id', object);
  }

  Id putByIdSync(MilestoneCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'id', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllById(List<MilestoneCollection> objects) {
    return putAllByIndex(r'id', objects);
  }

  List<Id> putAllByIdSync(List<MilestoneCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'id', objects, saveLinks: saveLinks);
  }
}

extension MilestoneCollectionQueryWhereSort
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QWhere> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhere>
      anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MilestoneCollectionQueryWhere
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QWhereClause> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      idEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'id',
        value: [id],
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterWhereClause>
      idNotEqualTo(String id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [id],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'id',
              lower: [],
              upper: [id],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MilestoneCollectionQueryFilter on QueryBuilder<MilestoneCollection,
    MilestoneCollection, QFilterCondition> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'driveFileId',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'driveFileId',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'driveFileId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'driveFileId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'driveFileId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'driveFileId',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      driveFileIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'driveFileId',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      eventDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eventDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      eventDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eventDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      eventDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eventDate',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      eventDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eventDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      isPublicEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPublic',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'latitude',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'latitude',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      latitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'latitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'locationName',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'locationName',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'locationName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'locationName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'locationName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'locationName',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      locationNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'locationName',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'longitude',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'longitude',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      longitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'media',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'participants',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'participants',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'participants',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'participants',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'participants',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      participantsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'participants',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusEqualTo(
    SyncStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusGreaterThan(
    SyncStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusLessThan(
    SyncStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusBetween(
    SyncStatus lower,
    SyncStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      syncStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension MilestoneCollectionQueryObject on QueryBuilder<MilestoneCollection,
    MilestoneCollection, QFilterCondition> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterFilterCondition>
      mediaElement(FilterQuery<MediaAssetEmbed> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'media');
    });
  }
}

extension MilestoneCollectionQueryLinks on QueryBuilder<MilestoneCollection,
    MilestoneCollection, QFilterCondition> {}

extension MilestoneCollectionQuerySortBy
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QSortBy> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByDriveFileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'driveFileId', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByDriveFileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'driveFileId', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByEventDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventDate', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByEventDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventDate', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByIsPublic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublic', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByIsPublicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublic', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLocationName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locationName', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLocationNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locationName', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension MilestoneCollectionQuerySortThenBy
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QSortThenBy> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByDriveFileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'driveFileId', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByDriveFileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'driveFileId', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByEventDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventDate', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByEventDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eventDate', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByIsPublic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublic', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByIsPublicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPublic', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLocationName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locationName', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLocationNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'locationName', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenBySyncStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenBySyncStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncStatus', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QAfterSortBy>
      thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension MilestoneCollectionQueryWhereDistinct
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct> {
  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByDriveFileId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'driveFileId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByEventDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eventDate');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctById({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByIsPublic() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPublic');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latitude');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByLocationName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'locationName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longitude');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByParticipants() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'participants');
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctBySyncStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MilestoneCollection, MilestoneCollection, QDistinct>
      distinctByUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension MilestoneCollectionQueryProperty
    on QueryBuilder<MilestoneCollection, MilestoneCollection, QQueryProperty> {
  QueryBuilder<MilestoneCollection, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<MilestoneCollection, String, QQueryOperations>
      categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<MilestoneCollection, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MilestoneCollection, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<MilestoneCollection, String?, QQueryOperations>
      driveFileIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'driveFileId');
    });
  }

  QueryBuilder<MilestoneCollection, DateTime, QQueryOperations>
      eventDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eventDate');
    });
  }

  QueryBuilder<MilestoneCollection, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MilestoneCollection, bool, QQueryOperations> isPublicProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPublic');
    });
  }

  QueryBuilder<MilestoneCollection, double?, QQueryOperations>
      latitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latitude');
    });
  }

  QueryBuilder<MilestoneCollection, String?, QQueryOperations>
      locationNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'locationName');
    });
  }

  QueryBuilder<MilestoneCollection, double?, QQueryOperations>
      longitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longitude');
    });
  }

  QueryBuilder<MilestoneCollection, List<MediaAssetEmbed>, QQueryOperations>
      mediaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'media');
    });
  }

  QueryBuilder<MilestoneCollection, List<String>, QQueryOperations>
      participantsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'participants');
    });
  }

  QueryBuilder<MilestoneCollection, SyncStatus, QQueryOperations>
      syncStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncStatus');
    });
  }

  QueryBuilder<MilestoneCollection, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<MilestoneCollection, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
